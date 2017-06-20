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
 

class Tasha extends CI_Controller {

	public function index()
	{
		$height = isset($_REQUEST['height']) ? $_REQUEST['height'] : 160;
		$width = isset($_REQUEST['width']) ? $_REQUEST['width'] : 128;
		$url = "http://electricimp.com/images/imp-logo-trim.png";
		$url = isset($_REQUEST['url']) ? $_REQUEST['url'] : $url;
		$hash = "application/cache/" . md5("tasha".print_r($_REQUEST, true));

		// Check the cache first
		if (is_readable("$hash/frame_XXX_t.bin")) {
			return $this->readfile("$hash/frame_XXX_t.bin");
		}

		// Prep the cache if its not already loaded
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

				$geo = $frame->getImageGeometry();
				$w = $geo['width'];
				$h = $geo['height'];

				$final = new Imagick();
				$final->newImage($width, $height, new ImagickPixel('black')); 
				$final->compositeImage($frame, imagick::COMPOSITE_COPY, ($width - $w) / 2, ($height - $h) / 2);
				$final->setImageFormat('gif'); 
				$final->writeImage(sprintf("$hash/frame_%03d_t.gif", $f));

				$f++;
			}
		}

		// Now out put the image frames
		$bin = ""; $h = $w = 0;
		for ($f = 0; true; $f++) {
			$fn_t = sprintf("$hash/frame_%03d_t.gif", $f);
			if (is_readable($fn_t)) {
				$img = new Imagick($fn_t);

				$geo = $img->getImageGeometry();
				$w = $geo['width'];
				$h = $geo['height'];

				// Extract every pixel, one at a time. 
				$pixels = $img->exportImagePixels(0, 0, $w, $h, "RGB", Imagick::PIXEL_CHAR);

				for ($i = 0; $i < count($pixels); $i += 3) {
					$r = ($pixels[$i+0] >> 3) & 0x1F;
					$g = ($pixels[$i+1] >> 2) & 0x3F;
					$b = ($pixels[$i+2] >> 3) & 0x1F;
					$rgb16 = ($r << 11) | ($g << 5) | ($b);
					$bin .= pack("n", $rgb16);
				}
			} else {
				break;
			}
		}

		// Write out the cash
		file_put_contents("$hash/frame_XXX_t.bin", $bin);
		unset($bin);

		// Finished!
		return $this->readfile("$hash/frame_XXX_t.bin");
	}


	protected function readfile($filename) {

		$length = $filesize = filesize($filename);
		$offset = 0;

		if ( isset($_SERVER['HTTP_RANGE']) ) {
			// if the HTTP_RANGE header is set we're dealing with partial content
			$partialContent = true;

			// find the requested range (assuming only one range)
			preg_match('/bytes=(\d+)-(\d+)?/', $_SERVER['HTTP_RANGE'], $matches);

			$offset = intval($matches[1]);
			$length = intval($matches[2]) - $offset;

			if ($offset >= $filesize) {
				header('HTTP/1.1 416 Requested Range Not Satisfiable');
				header('Content-Range: bytes */' . $filesize); 
				exit;
			}

		} else {
			$partialContent = false;
		}

		// seek to the requested offset, this is 0 if it's not a partial content request
		$file = fopen($filename, 'r');
		fseek($file, $offset);
		$data = fread($file, $length);
		fclose($file);

		if ($partialContent) {
			// output the right headers for partial content
			header('HTTP/1.1 206 Partial Content');
			header('Content-Range: bytes ' . $offset . '-' . ($offset + $length) . '/' . $filesize);
			header('Content-Length: ' . $length);
		} else {
			header('Content-Length: ' . $filesize);
		}

		header("Content-type: application/octet-stream");
		header('Content-Disposition: attachment; filename="image.bin"');
		header('Accept-Ranges: bytes');

		// don't forget to send the data too
		print($data);
	}

}

/* End of file bandw.php */
/* Location: ./application/controllers/tasha.php */
