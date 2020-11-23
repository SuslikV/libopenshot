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
	ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH create blank");
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
	ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH create with parameters");
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
	ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH destroy");
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
	info.description = "FFmpeg's static video filters for the frame's image.";
	info.has_audio = false;
	info.has_video = true;
}

// This method is required for all derived classes of EffectBase, and returns a
// modified openshot::Frame object
std::shared_ptr<Frame> FFmpegWYH::GetFrame(std::shared_ptr<Frame> frame, int64_t frame_number)
{
	// Next code is assuming that QImage and AVFrame data formats (image planes) equals
	// Parse text field to get clear filter graph
	// std::string filter_graph_txt = "123\n456\n789\n1z3\n4y6\n7c9\n1v3\n";

	std::string part_only = "";
	std::string version_str = "";
	std::string comment_str = "";
	std::string description_str = "";
	std::string arg_str = "";

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
	int pixels_data_size = frame_image->bytesPerLine() * frame_image->height();

	// streamline the text
	std::istringstream full_txt(filter_graph_txt);

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

	// std::to_string((int) PIX_FMT_RGBA) == 26
	description_str = "buffer=video_size=" + std::to_string(w) + "x"+ std::to_string(h) + ":pix_fmt=26:time_base=1/25:pixel_aspect=1/1 " + description_str;

	// in file part:
	// "[in_1];movie=C\\:\\\\Temp\\\\clut_ffmpeg_shift_exposure.png [clut];[in_1][clut] haldclut [result];[result] buffersink"

	if (last_description_str != description_str) {
		// remember new filter description
		last_description_str = description_str;
	} else if ((graph) && (last_width == w) && (last_height == h)) {
			// graph is the same, no init, no parsing needed,
			// if it is already exist (graph destroyed on fail)
			ZmqLogger::Instance()->AppendDebugMethod("graph is the same");
			goto data_feed;
		}

	// remember new values
	last_width = w;
	last_height = h;

	// Frame modifications are starts from here

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

	ZmqLogger::Instance()->AppendDebugMethod("filters names from graph");
	// look for the output buffersink full name (like "Parsed_buffersink_3"), backward because it always lies close to the end
	for (i = graph->nb_filters - 1; i >= 0; i--)
		if (graph->filters[i]->name) {
			filter_name = std::string(graph->filters[i]->name);
			ZmqLogger::Instance()->AppendDebugMethod(filter_name, "i", i);
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

	ZmqLogger::Instance()->AppendDebugMethod("src_frame prop1", "w", src_frame->width, "h", src_frame->height, "format", src_frame->format, "range", src_frame->color_range);

	// allocate buffer and pointers for the src_frame
	if (av_frame_is_writable(src_frame) == 0) { // if src_frame not writable then...
		ret = av_frame_get_buffer(src_frame, 1);
		if (ret < 0) {
			// skip further processing
			func_fail = 80;
			goto end;
		}
	}

	ZmqLogger::Instance()->AppendDebugMethod("src_frame 0", "av_frame_is_writable", av_frame_is_writable(src_frame));
	ZmqLogger::Instance()->AppendDebugMethod("src_frame prop2", "w", src_frame->width, "h", src_frame->height, "format", src_frame->format, "range", src_frame->color_range);

	// copy of src_frame linesizes (only 4 of them)
	int src_linesize[4];
	src_linesize[0] = src_frame->linesize[0];
	src_linesize[1] = src_frame->linesize[1];
	src_linesize[2] = src_frame->linesize[2];
	src_linesize[3] = src_frame->linesize[3];
	//memcpy(&src_linesize, &src_frame->linesize, sizeof(src_linesize));
	//int src_linesize[AV_NUM_DATA_POINTERS];
	//memcpy(&src_linesize, &src_frame->linesize, sizeof(src_frame->linesize));

	// Fill AVFrame with actual data
	ZmqLogger::Instance()->AppendDebugMethod("img bytes perline", "bytesPerLine", frame_image->bytesPerLine(), "pixels_data_size", pixels_data_size);
	ZmqLogger::Instance()->AppendDebugMethod("AVFrame src_frame", "[0]", src_frame->linesize[0], "[1]", src_frame->linesize[1], "[2]", src_frame->linesize[2], "[3]", src_frame->linesize[3]);
	ZmqLogger::Instance()->AppendDebugMethod("src_frame prop3", "w", src_frame->width, "h", src_frame->height, "format", src_frame->format, "range", src_frame->color_range);
	ZmqLogger::Instance()->AppendDebugMethod("src_frame 1", "av_frame_is_writable", av_frame_is_writable(src_frame));

	// copy frame_image data into src_frame (not filtered yet)
	// source has no data[4] pointers but single one
	memcpy(src_frame->data[0], pixels, pixels_data_size);

	ZmqLogger::Instance()->AppendDebugMethod("image copy done");
	ZmqLogger::Instance()->AppendDebugMethod("src_frame prop4", "w", src_frame->width, "h", src_frame->height, "format", src_frame->format, "range", src_frame->color_range);
	ZmqLogger::Instance()->AppendDebugMethod("src_frame 2", "av_frame_is_writable", av_frame_is_writable(src_frame));

	// load picture into input buffer
	ret = av_buffersrc_add_frame(in_buf_src_ctx, src_frame);
	if (ret < 0) {
		// skip further processing
		func_fail = 90;
		goto end;
	}

	// building filtered AVFarme
	filtered_frame = av_frame_alloc();

	ZmqLogger::Instance()->AppendDebugMethod("src_frame 3", "av_frame_is_writable", av_frame_is_writable(src_frame));
	ZmqLogger::Instance()->AppendDebugMethod("AVFrame filtered_frame 2", "av_frame_is_writable", av_frame_is_writable(filtered_frame));

	// get filtered picture from the output buffer
	ret = av_buffersink_get_frame(sink_buf_ctx, filtered_frame);
	if (ret < 0) {
		// free FFmpeg filtered resouces
		ZmqLogger::Instance()->AppendDebugMethod("av_frame_free filtered"); // string only
		av_frame_free(&filtered_frame); // struct itself (holds only pointers to buffers)

		// skip further processing
		func_fail = 100;
		goto end;
	}

	ZmqLogger::Instance()->AppendDebugMethod("src_frame 4", "av_frame_is_writable", av_frame_is_writable(src_frame));
	ZmqLogger::Instance()->AppendDebugMethod("AVFrame filtered_frame 3", "av_frame_is_writable", av_frame_is_writable(filtered_frame));
	ZmqLogger::Instance()->AppendDebugMethod("AVFrame filtered linesize", "[0]", filtered_frame->linesize[0], "[1]", filtered_frame->linesize[1], "[2]", filtered_frame->linesize[2], "[3]", filtered_frame->linesize[3]);
	ZmqLogger::Instance()->AppendDebugMethod("AVFrame filtered", "w", filtered_frame->width, "h", filtered_frame->height, "format", filtered_frame->format, "range", filtered_frame->color_range);

	// check for final pixel format of the image if any was changed
	if (filtered_frame->format != PIX_FMT_RGBA) {
		// skip further processing
		func_fail = 110;
		goto end;
	}

	// check for final image linesizes if any was changed
	if (memcmp(&src_linesize, &filtered_frame->linesize, sizeof(src_linesize)) != 0) {
		// skip further processing
		func_fail = 120;
		goto end;
	}

	// check for final size of the image if any was changed
	if (filtered_frame->width != w || filtered_frame->height != h) {
		// skip further processing
		func_fail = 130;
		goto end;
	}

	// check for final range of the image if any was changed
	if (filtered_frame->color_range != AVCOL_RANGE_JPEG) {
		// skip further processing
		func_fail = 140;
		goto end;
	}

	// copy filtered_frame data back to frame
	memcpy(pixels, filtered_frame->data[0], pixels_data_size);

end:
	// Debug output
	ZmqLogger::Instance()->AppendDebugMethod("FFmpegWYH::GetFrame", "ret", ret, "func_fail", func_fail);
	ZmqLogger::Instance()->AppendDebugMethod(description_str); // string only

	last_processing_status = func_fail;

	// free FFmpeg filtered resouces
	if (filtered_frame) {
		ZmqLogger::Instance()->AppendDebugMethod("av_frame_free filtered"); // string only
		av_frame_free(&filtered_frame); // struct itself (holds only pointers to buffers)
	}

	if (func_fail != 0) {
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
}

void FFmpegWYH::free_in_buffer()
{
	// free FFmpeg buffer resouces
	if (src_frame) {
		ZmqLogger::Instance()->AppendDebugMethod("av_frame_free"); // string only
		av_frame_free(&src_frame); // struct itself (holds only pointers to buffers)
	}
}

void FFmpegWYH::free_graph()
{
	// free graph
	if (graph) {
		//av_frame_unref(src_frame); if AVFrame is reused between calls (no new memory allocations)
		ZmqLogger::Instance()->AppendDebugMethod("avfilter_graph_free"); // string only
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
	return std::string("Failed (" + std::to_string(last_processing_status) + ")");
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
