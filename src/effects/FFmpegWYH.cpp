/**
 * @file
 * @brief Source file for FFmpegWYH class
 * @author Suslik V
 *
 */

#include "../../include/effects/FFmpegWYH.h"

using namespace openshot;

/// Blank constructor, useful when using Json to load the effect properties
FFmpegWYH::FFmpegWYH() : P1(0.0), P2(0.0), P3(0.0), P4(0.0) {
	filter_graph_txt = "...";
	friendly_name_str = "";
	last_processing_status = 0;
	last_description_str = "";
	last_width = 0;
	last_height = 0;
	// Init effect properties
	init_effect_details();
}

// Default constructor
FFmpegWYH::FFmpegWYH(std::string new_filter_graph_txt, Keyframe new_P1, Keyframe new_P2, Keyframe new_P3, Keyframe new_P4)
{
	filter_graph_txt = new_filter_graph_txt;
	friendly_name_str = "";
	last_processing_status = 0;
	last_description_str = "";
	last_width = 0;
	last_height = 0;
	P1 = new_P1;
	P2 = new_P2;
	P3 = new_P3;
	P4 = new_P4;
	// Init effect properties
	init_effect_details();
}

// Destructor
FFmpegWYH::~FFmpegWYH() {
	ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH:: - destroy");
	// free FFmpeg buffer resources
	free_in_buffer();
	free_graph();
}

// Init effect settings
void FFmpegWYH::init_effect_details()
{
	/// Initialize the values of the EffectInfo struct.
	InitEffectInfo();

	/// Set the effect info
	info.class_name = "FFmpegWYH";
	info.name = "Video Filter";
	info.description = "FFmpeg based static video filters for the frame's image.";
	info.has_audio = false;
	info.has_video = true;
}

// This method is required for all derived classes of EffectBase, and returns a
// modified openshot::Frame object
std::shared_ptr<Frame> FFmpegWYH::GetFrame(std::shared_ptr<Frame> frame, int64_t frame_number)
{
	// Next code is assuming that QImage and AVFrame data formats (image planes) equals

	std::string part_only = "";
	std::string version_str = "";
	//std::string comment_str = ""; // not in use
	std::string description_str = "";
	std::string arg_str = "";
	std::string sws_flags_str = "sws_flags=fast_bilinear";

	friendly_name_str = "";

	// FFmpeg errors return values
	int ret = 0;
	int func_fail = 0;

	AVFrame *filtered_frame = NULL;

	char *filters_txt;
	std::string filter_name = "";

	// Get the frame's image
	std::shared_ptr<QImage> frame_image = frame->GetImage();

	// Get data pixels and image size
	uint8_t *pixels = (uint8_t *) frame_image->scanLine(0);
	int w = frame_image->width();
	int h = frame_image->height();
	int line = frame_image->bytesPerLine();
	int pixels_data_size = frame_image->bytesPerLine() * frame_image->height();

	// streamline the text
	std::istringstream full_txt(filter_graph_txt);

	// Parse text field to get clear filter graph
	int i = 0;
	while((i<5) && getline(full_txt, part_only)) {
		++i;
		if (i == 1) {
			version_str = part_only;
		} else if (i == 2) {
			friendly_name_str = part_only;
		} else if (i == 4) {
			description_str = part_only;
		}
	};

	// skip further processing when version mismatch or empty file
	if (version_str != "v1" && version_str != "v2" || description_str == "") {
		// skip further processing
		func_fail = 10;
		goto end;
	}

	// v2 supports dynamic replacement of P_1..P_4 keys
	if (version_str == "v2") {
		// Get keyframe values for this frame as string
		std::string P1_str = std::to_string(P1.GetValue(frame_number));
		std::string P2_str = std::to_string(P2.GetValue(frame_number));
		std::string P3_str = std::to_string(P3.GetValue(frame_number));
		std::string P4_str = std::to_string(P4.GetValue(frame_number));

		description_str = std::regex_replace(description_str, std::regex("P_1"), P1_str);
		description_str = std::regex_replace(description_str, std::regex("P_2"), P2_str);
		description_str = std::regex_replace(description_str, std::regex("P_3"), P3_str);
		description_str = std::regex_replace(description_str, std::regex("P_4"), P4_str);
	}

	if (openshot::Settings::Instance()->HIGH_QUALITY_SCALING)
		sws_flags_str = "sws_flags=bicubic";

	// no simplifications for chroma scaling if any will take place
	// anyway it is better to not use the filters that doesn't supports RGBA
	sws_flags_str += "+accurate_rnd+full_chroma_int";

	if (friendly_name_str == "debug")
		sws_flags_str += "+print_info";

	sws_flags_str += "; ";

	// std::to_string((int) PIX_FMT_RGBA) == 26
	description_str = sws_flags_str + "buffer=video_size=" + std::to_string(w) + "x"+ std::to_string(h) + ":pix_fmt=26:time_base=1/25:pixel_aspect=1/1 " + description_str;

	// in file part:
	// "[in_1];movie=C\\:\\\\Temp\\\\clut_ffmpeg_shift_exposure.png [clut];[in_1][clut] haldclut [result];[result] buffersink"

	if (last_description_str != description_str) {
		// remember new filter description
		last_description_str = description_str;
	} else if ((graph) && (last_width == w) && (last_height == h)) {
			// graph is the same, no init, no parsing needed
			// when it already exist (graph destroyed on fail)
			ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame - graph is the same");
			goto data_feed;
		}

	// remember new values
	last_width = w;
	last_height = h;

	// AVFilterGraph and AVFrame related modifications are starts from here

	// useful link https://github.com/KDE/ffmpegthumbs/blob/master/ffmpegthumbnailer/moviedecoder.cpp

	// Get new graph
	free_graph();
	graph = avfilter_graph_alloc();
	if (graph == NULL) {
		// skip further processing
		func_fail = 20;
		goto end;
	}

	// final filter graph description string
	filters_txt = &description_str[0];

	ret = avfilter_graph_parse2(graph, filters_txt, &f_inps, &f_outps);
	if (ret < 0) {
		// parse graph error
		// skip further processing
		func_fail = 30;
		goto end;
	}

	if (f_inps || f_outps) {
		// some not connected in/outs
		// skip further processing
		func_fail = 40;
		goto end;
	}

	ret = avfilter_graph_config(graph, NULL);
	if (ret < 0) {
		// config graph error
		// skip further processing
		func_fail = 50;
		goto end;
	}

	// look for the output buffersink full name (like "Parsed_buffersink_3"), backward because it always lies close to the end
	for (i = graph->nb_filters - 1; i >= 0; i--)
		if (graph->filters[i]->name) {
			filter_name = std::string(graph->filters[i]->name);
			ZmqLogger::Instance()->AppendDebugMethod(std::string("FFmpegWYH::GetFrame name:" + filter_name), "i", i);
			if (filter_name.compare(0, std::string("Parsed_buffersink").length(), "Parsed_buffersink") == 0)
				break;
		}

	// get buffers to load source and get final picture
	in_buf_src_ctx = avfilter_graph_get_filter(graph, "Parsed_buffer_0");
	if (in_buf_src_ctx == NULL) {
		// skip further processing
		func_fail = 60;
		goto end;
	}

	sink_buf_ctx = avfilter_graph_get_filter(graph, &filter_name[0]);
	if (sink_buf_ctx == NULL) {
		// skip further processing
		func_fail = 70;
		goto end;
	}

	// prepare for new in buffers allocation (for each new graph use new src_frame)
	free_in_buffer();

data_feed:
	// Get new source AVFrame
	frame_reinit();
	if (src_frame == NULL) {
		// skip further processing
		func_fail = 75;
		goto end;
	}

	// allocate buffer and pointers for the src_frame
	if (av_frame_is_writable(src_frame) == 0) { // if src_frame not writable then get new buffers
		ret = av_frame_get_buffer(src_frame, 0); // alignment always is set to 32
		if (ret < 0) {
			// skip further processing
			func_fail = 80;
			goto end;
		}
	}

	// copy of src_frame linesizes (only 4 of them)
	int src_linesize[4];
	src_linesize[0] = src_frame->linesize[0];
	src_linesize[1] = src_frame->linesize[1];
	src_linesize[2] = src_frame->linesize[2];
	src_linesize[3] = src_frame->linesize[3];
	//memcpy(&src_linesize, &src_frame->linesize, sizeof(src_linesize));

	// assuming that the frame_image is not bigger than the allocated AVFrame
	if (line > src_linesize[0]) {
		// skip further processing
		func_fail = 85;
		goto end;
	}

	// fill AVFrame with actual data
	// copy frame_image data into src_frame (not filtered yet)
	// source has no data[4] pointers but single one
	// taking into account the linesize of the frame_image
	// both images are RGBA with no planes (packed RRGGBBAA) and has one linesize field
	//memcpy(src_frame->data[0], pixels, pixels_data_size);
	for (int k = 0; k < h; k++) {
		memcpy(src_frame->data[0] + k * src_linesize[0], pixels + k * line, line);
	}

	ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame - image copy done");

	// load picture into input buffer
	ret = av_buffersrc_add_frame(in_buf_src_ctx, src_frame);
	if (ret < 0) {
		// skip further processing
		func_fail = 90;
		goto end;
	}

	// building filtered AVFarme
	filtered_frame = av_frame_alloc();

	// get filtered picture from the output buffer
	ret = av_buffersink_get_frame(sink_buf_ctx, filtered_frame);
	if (ret < 0) {
		// free FFmpeg filtered resouces
		av_frame_free(&filtered_frame);

		// skip further processing
		func_fail = 100;
		goto end;
	}

	// check for final pixel format of the image if any was changed
	if (filtered_frame->format != PIX_FMT_RGBA) {
		ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame filtered_frame", "format", filtered_frame->format);
		// skip further processing
		func_fail = 110;
		goto end;
	}

	// check for final size of the image if any was changed
	if (filtered_frame->width != w || filtered_frame->height != h) {
		ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame frame_image", "w", w, "h", h);
		ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame filtered_frame", "w", filtered_frame->width, "h", filtered_frame->height);
		// skip further processing
		func_fail = 120;
		goto end;
	}

	// check for final image linesizes if any (but first) was changed
	if (memcmp(&src_linesize + sizeof(int), &filtered_frame->linesize + sizeof(int), sizeof(src_linesize) - sizeof(int)) != 0) {
		ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame src linesize", "[0]", src_linesize[0], "[1]", src_linesize[1], "[2]", src_linesize[2], "[3]", src_linesize[3]);
		ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame filtered linesize", "[0]", filtered_frame->linesize[0], "[1]", filtered_frame->linesize[1], "[2]", filtered_frame->linesize[2], "[3]", filtered_frame->linesize[3]);
		// skip further processing
		func_fail = 130;
		goto end;
	}

	// check for final range of the image if any was changed
	if (filtered_frame->color_range != AVCOL_RANGE_JPEG) {
		ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame filtered_frame", "range", filtered_frame->color_range);
		// skip further processing
		func_fail = 140;
		goto end;
	}

	// copy filtered_frame data back to frame taking into account
	// linesize of the frame_image
	for (int j = 0; j < h; j++) {
		memcpy(pixels + j * line, filtered_frame->data[0] + j * filtered_frame->linesize[0], line);
	}

end:
	last_processing_status = func_fail;

	// free FFmpeg filtered resouces
	if (filtered_frame) {
		av_frame_free(&filtered_frame);
	}

	if (func_fail != 0) {
		// Debug output
		ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame", "ret", ret, "func_fail", func_fail);
		ZmqLogger::Instance()->AppendDebugMethod(description_str); // string only

		free_in_buffer();
		free_graph();
	}

	// return the modified frame
	return frame;
}

void FFmpegWYH::frame_reinit()
{
	//free_in_buffer();

	// building AVFarme
	if (!src_frame)
		src_frame = av_frame_alloc();
	src_frame->width = last_width;
	src_frame->height = last_height;
	src_frame->format = PIX_FMT_RGBA;
	src_frame->color_range = AVCOL_RANGE_JPEG;
	// 4:2:0 only properties
	//src_frame->color_primaries = AVCOL_PRI_BT709;
	//src_frame->color_trc = AVCOL_TRC_BT709;
	//src_frame->colorspace = AVCOL_SPC_BT709;
	//src_frame->chroma_location = AVCHROMA_LOC_LEFT;

	// some filters may use framesync, so set frame as having 0 pts here
	src_frame->pts = 0;
}

void FFmpegWYH::free_in_buffer()
{
	// free FFmpeg buffer resouces
	if (src_frame) {
		av_frame_free(&src_frame);
	}
}

void FFmpegWYH::free_graph()
{
	// free graph
	if (graph) {
		avfilter_graph_free(&graph);
		graph = NULL;
	}
}

// Generate string for status of the frame processing
std::string FFmpegWYH::FrameProcessingStatus() const {

	// Return last status as string
	if (last_processing_status == 0) {
		return std::string("OK");
	}

	std::string msg;
	switch (last_processing_status) {
		case  10: msg = "Ver./Graph string empty";   break;
		case  20: msg = "No RAM for graph";          break;
		case  30: msg = "Graph syntax error";        break;
		case  40: msg = "Some In/Out not connected"; break;
		case  50: msg = "Graph config failed";       break;
		case  60: msg = "Input buff not found";      break;
		case  70: msg = "Output buff not found";     break;
		case  75: msg = "No RAM for frame stuct";    break;
		case  80: msg = "No RAM for frame buff";     break;
		case  85: msg = "Src linesize > Dst";        break;
		case  90: msg = "Load into buff failed";     break;
		case 100: msg = "Get from buff failed";      break;
		case 110: msg = "Not RGBA final format";     break;
		case 120: msg = "Final size(WxH) changed";   break;
		case 130: msg = "Not packed RGBA format";    break;
		case 140: msg = "Color Range != PC";         break;
		default : msg = "Unknown";
	}

	return std::string("(" + std::to_string(last_processing_status) + ") " + msg);
}

// Generate JSON string of this object
std::string FFmpegWYH::Json() const {

	// Return formatted string
	return JsonValue().toStyledString();
}

// Generate Json::Value for this object
Json::Value FFmpegWYH::JsonValue() const {

	// Create root json object
	Json::Value root = EffectBase::JsonValue(); // get parent properties
	root["type"] = info.class_name;
	root["ffgraph"] = filter_graph_txt;
	root["P1"] = P1.JsonValue();
	root["P2"] = P2.JsonValue();
	root["P3"] = P3.JsonValue();
	root["P4"] = P4.JsonValue();

	// return JsonValue
	return root;
}

// Load JSON string into this object
void FFmpegWYH::SetJson(const std::string value) {

	// Parse JSON string into JSON objects
	try
	{
		const Json::Value root = openshot::stringToJson(value);
		// Set all values that match
		SetJsonValue(root);
	}
	catch (const std::exception& e)
	{
		// Error parsing JSON (or missing keys)
		throw InvalidJSON("JSON is invalid (missing keys or invalid data types)");
	}
}

// Load Json::Value into this object
void FFmpegWYH::SetJsonValue(const Json::Value root) {

	// Set parent data
	EffectBase::SetJsonValue(root);

	// Set data from Json (if key is found)
	if (!root["ffgraph"].isNull())
		filter_graph_txt = root["ffgraph"].asString();
	if (!root["P1"].isNull())
		P1.SetJsonValue(root["P1"]);
	if (!root["P2"].isNull())
		P2.SetJsonValue(root["P2"]);
	if (!root["P3"].isNull())
		P3.SetJsonValue(root["P3"]);
	if (!root["P4"].isNull())
		P4.SetJsonValue(root["P4"]);
}

// Get all properties for a specific frame
std::string FFmpegWYH::PropertiesJSON(int64_t requested_frame) const {

	// Generate JSON properties list
	Json::Value root;
	root["id"] = add_property_json("ID", 0.0, "string", Id(), NULL, -1, -1, true, requested_frame);
	root["position"] = add_property_json("Position", Position(), "float", "", NULL, 0, 30 * 60 * 60 * 48, false, requested_frame);
	root["layer"] = add_property_json("Track", Layer(), "int", "", NULL, 0, 20, false, requested_frame);
	root["start"] = add_property_json("Start", Start(), "float", "", NULL, 0, 30 * 60 * 60 * 48, false, requested_frame);
	root["end"] = add_property_json("End", End(), "float", "", NULL, 0, 30 * 60 * 60 * 48, false, requested_frame);
	root["duration"] = add_property_json("Duration", Duration(), "float", "", NULL, 0, 30 * 60 * 60 * 48, true, requested_frame);

	// Filter file with graph description
	root["ffgraph"] = add_property_json("Filter File", 0.0, "string", filter_graph_txt, NULL, -1, -1, false, requested_frame);
	
	// Messages
	root["ffFilterName"] = add_property_json("Name", 0.0, "string", friendly_name_str, NULL, -1, -1, true, requested_frame);
	root["ffFilterStatus"] = add_property_json("Status", 0.0, "string", FrameProcessingStatus(), NULL, -1, -1, true, requested_frame);

	// Keyframes
	root["P1"] = add_property_json("P1", P1.GetValue(requested_frame), "float", "", &P1, -1000000.0, 1000000.0, false, requested_frame);
	root["P2"] = add_property_json("P2", P2.GetValue(requested_frame), "float", "", &P2, -1000000.0, 1000000.0, false, requested_frame);
	root["P3"] = add_property_json("P3", P3.GetValue(requested_frame), "float", "", &P3, -1000000.0, 1000000.0, false, requested_frame);
	root["P4"] = add_property_json("P4", P4.GetValue(requested_frame), "float", "", &P4, -1000000.0, 1000000.0, false, requested_frame);

	// Return formatted string
	return root.toStyledString();
}
