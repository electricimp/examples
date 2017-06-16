<?php if ( ! defined('BASEPATH')) exit('No direct script access allowed');

/*
Copyright (C) 2013 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
 

class BandW extends CI_Controller {

	// Generates a binary stream of data representing a version of the provided image (url) that has been
	// stripped down to black-and-white and scaled to the provided size.
	public function index()
	{
		$height = isset($_REQUEST['height']) ? $_REQUEST['height'] : 384;
		$width = isset($_REQUEST['width']) ? $_REQUEST['width'] : 384;
		$url = "http://electricimp.com/images/imp-logo-trim.png";
		$url = isset($_REQUEST['url']) ? $_REQUEST['url'] : $url;
		$hash = "application/cache/" . md5(print_r($_REQUEST, true));

		header("Content-type: application/octet-stream");
		header('Content-Disposition: attachment; filename="image.bin"');

		// Load the cache if its not already loaded
		if (!is_readable($hash)) {
			mkdir($hash);

			// Create a new imagick object and read in the image
			file_put_contents("$hash/frame_XXX_o.gif", file_get_contents($url));
			$img = new Imagick("$hash/frame_XXX_o.gif");

			// Flatten the frame layers
			$img = $img->coalesceImages();

			$f = 0;
			foreach ($img as $frame) {
				// Resize each frame and store the original and thumbnail frames
				$frame->writeImage(sprintf("$hash/frame_%03d_o.gif", $f));
				$frame->thumbnailImage($width, $height, true);

				// Drop the colours to two using a threshold
				$max = $frame->getQuantumRange();
				$max = $max["quantumRangeLong"];
				$frame->thresholdImage(0.77 * $max);

				$frame->writeImage(sprintf("$hash/frame_%03d_t.gif", $f));
				$f++;
			}
		}


		// Now out put the image frames
		$bin = ""; $log = "";
		for ($f = 0; true; $f++) {
			$fn_t = sprintf("$hash/frame_%03d_t.gif", $f);
			if (is_readable($fn_t)) {
				$img = new Imagick($fn_t);

				$geo = $img->getImageGeometry();
				$w = $geo['width'];
				$h = $geo['height'];

				// Extract every pixel, one at a time. Red channel is sufficient as we have reduced it to black and white.
				$pixels = $img->exportImagePixels(0, 0, $w, $h, "R", Imagick::PIXEL_CHAR);

				$ch = 0x00;
				$pos = 7;
				$row = $col = 0;
				for ($i = 0; $i < count($pixels); $i++) {
					// Put the line header on the log
					if ($col == 0) {
						$log .= sprintf("%3d: ", $row+1);
					}

					// Is this black or white pixel?
					$pix = ($pixels[$i] != 0x00) ? 0x01 : 0x00;
					$ch = $ch | ($pix << $pos);
					$log .= $pix ? "\x23" : " ";

					// Are we at the end of a byte?
					if ($pos-- == 0) {
						$bin .= pack("C", ~$ch);
						$pos = 7;
						$ch = 0x00;
						$log .= " ";
					}

					// Are we at the end of a row?
					if ($col == $w-1) {
						$col = 0;
						$row++;
						if ($pos != 7) {
							// We need to output a half-finished byte.
							while ($pos >= 0) {
								$ch = $ch | (0x01 << $pos--);
							}
							$bin .= pack("C", ~$ch);
							$pos = 7;
							$ch = 0x00;
						}
						$log .= "\n";
					} else {
						$col++;
					}
				}
			} else {
				break;
			}
		}

		// Finished!
		// echo $log . "\n";
		echo pack("NN", $w, $h) . $bin;
	}

}

/* End of file bandw.php */
/* Location: ./application/controllers/bandw.php */
