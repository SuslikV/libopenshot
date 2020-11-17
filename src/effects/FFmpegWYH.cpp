/**
 * @file
 * @brief Source file for FFmpegWYH class
 * @author Suslik V
 *
 */

#include "../../include/effects/FFmpegWYH.h"

using namespace openshot;

/// Blank constructor, useful when using Json to load the effect properties
FFmpegWYH::FFmpegWYH() : filter_graph_txt(""), P1(0.0), P2(0.0), P3(0.0), P4(0.0) {
	// Init effect properties
	init_effect_details();
}

// Default constructor
FFmpegWYH::FFmpegWYH(std::string new_filter_graph_txt, Keyframe new_P1, Keyframe new_P2, Keyframe new_P3, Keyframe new_P4) : filter_graph_txt(""), P1(0.0), P2(0.0), P3(0.0), P4(0.0)
{
	// Init effect properties
	init_effect_details();
}

// Init effect settings
void FFmpegWYH::init_effect_details()
{
	/// Initialize the values of the EffectInfo struct.
	InitEffectInfo();

	/// Set the effect info
	info.class_name = "FFmpegWYH";
	info.name = "Video Filter";
	info.description = "FFmpeg's video filters for the frame's image.";
	info.has_audio = false;
	info.has_video = true;
}

// This method is required for all derived classes of EffectBase, and returns a
// modified openshot::Frame object
std::shared_ptr<Frame> FFmpegWYH::GetFrame(std::shared_ptr<Frame> frame, int64_t frame_number)
{
	// Parse text field to get clear filter graph
	// std::string filter_graph_txt = "123\n456\n789\n1z3\n4y6\n7c9\n1v3\n";

	std::string part_only = "";
	std::string version_str = "";
	std::string friendly_name_str = "";
	std::string comment_str = "";
	std::string description_str = "";
	std::string arg_str = "";

	// streamline the text
	std::istringstream full_txt(filter_graph_txt);

	int i = 0;
	while((i<5) && getline(full_txt, part_only)) {
		++i;
		if (i == 1) {
			version_str = part_only;
		} else if (i == 4) {
			description_str = part_only;
		}
	};

	// skip further processing when version mismatch or empty file
	if (version_str != "v1" && version_str != "v2" || description_str == "")
		return frame;

	// Get keyframe values for this frame
	/*
	float P1_value = P1.GetValue(frame_number);
	float P2_value = P2.GetValue(frame_number);
	float P3_value = P3.GetValue(frame_number);
	float P4_value = P4.GetValue(frame_number);
	*/

	// v2 supports dynamic replacement of P_1..P_4 keys
	if (version_str == "v2") {
		std::string P1_str = std::to_string(P1.GetValue(frame_number));
		std::string P2_str = std::to_string(P2.GetValue(frame_number));
		std::string P3_str = std::to_string(P3.GetValue(frame_number));
		std::string P4_str = std::to_string(P4.GetValue(frame_number));

		description_str = std::regex_replace(description_str, std::regex("P_1"), P1_str);
		description_str = std::regex_replace(description_str, std::regex("P_2"), P2_str);
		description_str = std::regex_replace(description_str, std::regex("P_3"), P3_str);
		description_str = std::regex_replace(description_str, std::regex("P_4"), P4_str);
	}

	// Next code is assuming that QImage and AVFrame data formats (image planes) equals
	
	// Get the frame's image
	std::shared_ptr<QImage> frame_image = frame->GetImage();

	// Get data pixels
	uint8_t *pixels = (uint8_t *) frame_image->scanLine(0);
	int w = frame_image->width();
	int h = frame_image->height();
	int pixels_data_size = frame_image->bytesPerLine() * frame_image->height();

	// Frame modifications are starts from here

	// useful link https://github.com/KDE/ffmpegthumbs/blob/master/ffmpegthumbnailer/moviedecoder.cpp
	
	AVFilterGraph *graph;
	char *filters_txt;
	AVFilterInOut *f_inps = NULL, *f_outps = NULL;

	graph = avfilter_graph_alloc();
	if (graph == NULL) {
		// skip further processing
		return frame;
	}

	// std::to_string((int) PIX_FMT_RGBA) == 26
	description_str = "buffer=video_size=" + std::to_string(w) + "x"+ std::to_string(h) + ":pix_fmt=26:time_base=1/25:pixel_aspect=1/1 " + description_str;

	// in file part:
	// "[in_1];movie=C\\:\\\\Temp\\\\clut_ffmpeg_shift_exposure.png [clut];[in_1][clut] haldclut [result];[result] buffersink"

	// final filter graph description string
	filters_txt = &description_str[0];

	if (avfilter_graph_parse2(graph, filters_txt, &f_inps, &f_outps) < 0) {
		// parse graph error
		// skip further processing
		return frame;
	}

	if (f_inps || f_outps)
		// some not connected in/outs
		// skip further processing
		return frame;

	if (avfilter_graph_config(graph, NULL) < 0) {
		// config graph error
		// skip further processing
		return frame;
	}

	// building AVFarme
	AVFrame *filtered_frame;
	filtered_frame = av_frame_alloc();

	av_opt_set_int(filtered_frame, "width", w, 0);
	av_opt_set_int(filtered_frame, "height", h, 0);
	av_opt_set_int(sws_ctx, "format", (int) PIX_FMT_RGBA, 0);

	// allocate buffer and pointers for the filtered_frame
	if (av_image_alloc(filtered_frame->data, filtered_frame->linesize, w, h, PIX_FMT_RGBA, 1) < 0)
		// skip further processing
		return frame;

	// copy of filtered_frame linesizes
	int src_linesize[4];
	memcpy(&src_linesize, &filtered_frame->linesize, sizeof(src_linesize));

	// copy frame_image data into filtered_frame (not filtered yet)
	//av_image_copy(filtered_frame->data, filtered_frame->linesize, (const uint8_t **)f->data, src_linesize, PIX_FMT_RGBA, w, h);
	av_image_copy(filtered_frame->data, filtered_frame->linesize, pixels, src_linesize, PIX_FMT_RGBA, w, h);

	// get buffers to load source and get final picture
	in_buf_src_ctx = avfilter_graph_get_filter(graph, "Parsed_buffer_0");
	sink_buf_ctx = avfilter_graph_get_filter(graph, "Parsed_buffersink_2");

	// load picture into input buffer
	if (av_buffersrc_add_frame(in_buf_src_ctx, filtered_frame) < 0) {
		// skip further processing
		return frame;
	}

	// get filtered picture from the output buffer
	if (av_buffersink_get_frame(sink_buf_ctx, filtered_frame) < 0) {
		// skip further processing
		return frame;
	}

	// copy filtered_frame data back to frame
	memcpy(pixels, filtered_frame->data[0], pixels_data_size);
	
	// free graph
	if (graph) {
		av_freep(filtered_frame->data[0]); // frame data buffer (also pointer to the first component - R )
		av_frame_free(&filtered_frame); // struct itself (holds only pointers to buffers)
		//av_frame_unref(filtered_frame); if AVFrame is reused between calls (no new memory allocations)
		avfilter_graph_free(&graph);
		graph = NULL;
	}

	// return the modified frame
	return frame;
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
	root["ffgraph"] = add_property_json("Filter File", 0.0, "string", "", NULL, -1, -1, false, requested_frame);

	// Keyframes
	root["P1"] = add_property_json("P1", P1.GetValue(requested_frame), "float", "", &P1, -1000000.0, 1000000.0, false, requested_frame);
	root["P2"] = add_property_json("P2", P2.GetValue(requested_frame), "float", "", &P2, -1000000.0, 1000000.0, false, requested_frame);
	root["P3"] = add_property_json("P3", P3.GetValue(requested_frame), "float", "", &P3, -1000000.0, 1000000.0, false, requested_frame);
	root["P4"] = add_property_json("P4", P4.GetValue(requested_frame), "float", "", &P4, -1000000.0, 1000000.0, false, requested_frame);

	// Return formatted string
	return root.toStyledString();
}
