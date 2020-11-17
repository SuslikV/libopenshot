/**
 * @file
 * @brief Header file for FFmpegWYH class
 * @author Suslik V
 *
 */


#ifndef OPENSHOT_FFMPEGWYH_EFFECT_H
#define OPENSHOT_FFMPEGWYH_EFFECT_H

#include "../EffectBase.h"

#include <iostream>
#include <sstream>
#include <string>
#include <memory>

// c++11
#include <regex>

#include "../Exceptions.h"
#include "../Json.h"
#include "../KeyFrame.h"
#include "../ReaderBase.h"
#include "../FFmpegReader.h"
#include "../QtImageReader.h"
#include "../ChunkReader.h"

extern "C" {
	#include "libavfilter/avfilter.h"
}

namespace openshot
{

	/**
	 * @brief This class adjusts an image, and can be animated via params P1, P2..P4
	 * with openshot::Keyframe curves over time.
	 *
	 * Can create many different powerful effects using FFmpeg.
	 */
	class FFmpegWYH : public EffectBase
	{
	private:
		/// Init effect settings
		void init_effect_details();

	public:
		Keyframe P1; // Animated parameters
		Keyframe P2;
		Keyframe P3;
		Keyframe P4;
		
		std::string filter_graph_txt; // FFmpeg filter graph in text format

		/// Blank constructor, useful when using Json to load the effect properties
		FFmpegWYH();

		/// Default constructor, which takes FFmpeg graph in txt format.
		///
		/// @param new_P1 (from -1000000.0 to +1000000.0, 0 is default/"off")
		FFmpegWYH(std::string new_filter_graph_txt, Keyframe new_P1, Keyframe new_P2, Keyframe new_P3, Keyframe new_P4);

		/// @brief This method is required for all derived classes of EffectBase, and returns a
		/// modified openshot::Frame object
		///
		/// The frame object is passed into this method, and a frame_number is passed in which
		/// tells the effect which settings to use from its keyframes (starting at 1).
		///
		/// @returns The modified openshot::Frame object
		/// @param frame The frame object that needs the effect applied to it
		/// @param frame_number The frame number (starting at 1) of the effect on the timeline.
		std::shared_ptr<Frame> GetFrame(std::shared_ptr<Frame> frame, int64_t frame_number) override;

		/// Get and Set JSON methods
		std::string Json() const override; ///< Generate JSON string of this object
		void SetJson(const std::string value) override; ///< Load JSON string into this object
		Json::Value JsonValue() const override; ///< Generate Json::Value for this object
		void SetJsonValue(const Json::Value root) override; ///< Load Json::Value into this object

		/// Get all properties for a specific frame (perfect for a UI to display the current state
		/// of all properties at any time)
		std::string PropertiesJSON(int64_t requested_frame) const override;
	};

}

#endif
