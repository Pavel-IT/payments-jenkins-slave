#!/usr/bin/python
import sys,json;

def extractName(manifest, region):
    with open(manifest) as mani:
        content = json.load(mani)
        for build in content['builds']:
            artifactText = build['artifact_id'].split(':')
            if artifactText[0] == region:
                print artifactText[1]
                return

if __name__ == "__main__":
    extractName(sys.argv[1], sys.argv[2])