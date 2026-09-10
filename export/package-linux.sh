cd "${0%/*}"
rm -f ap-gen-tool-linux.zip
cd linux
mkdir -p games
mkdir -p data
mkdir -p wads
mkdir -p output
rm -f ap-gen-tool-linux.zip
zip ap-gen-tool-linux.zip ap_gen_tool.sh ap_gen_tool.x86_64 ap_gen_tool.pck games data wads output
mv ap-gen-tool-linux.zip ..

