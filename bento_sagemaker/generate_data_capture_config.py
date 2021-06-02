import sys
import json


if __name__ == '__main__':
    config = {
        "EnableCapture": True,
        "InitialSamplingPercentage": sys.argv[1],
        "DestinationS3Uri": sys.argv[2],
        "CaptureOptions": [
            {"CaptureMode": "Input"},
            {"CaptureMode": "Output"},
        ]
    }
    print(json.dumps(config))
