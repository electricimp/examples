#MIT License
#Copyright 2017 Electric Imp
#SPDX-License-Identifier: MIT
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#The above copyright notice and this permission notice shall be
#included in all copies or substantial portions of the Software.
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
#EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
#OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#OTHER DEALINGS IN THE SOFTWARE.

import requests
import json
import base64
import sys

name = sys.argv[2]
fileName = sys.argv[1]
galleryName = "<GALLERY NAME>"

link = "https://api.kairos.com/enroll"
appId = "<APP ID>"
appKey = "<APP KEY>"

header = {'Content-Type' : 'application/json',
           'app_id' : appId,
           'app_key' : appKey
           }

js =        json.dumps({
            "image" : base64.b64encode(open(fileName, "rb").read()).decode('ascii'),
            "subject_id" : name,
            "gallery_name" : galleryName
            })

r = requests.post(link, headers=header, data=js, verify=False)

if(r.status_code == requests.codes.ok):
    print "OK"
else:
    print "Fail"