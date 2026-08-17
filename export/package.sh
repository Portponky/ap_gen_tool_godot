cd windows
mkdir -p games
mkdir -p data
mkdir -p wads
mkdir -p output
rm -f ap-gen-tool-windows.zip
zip ap-gen-tool-windows.zip ap_gen_tool.exe ap_gen_tool.pck games data wads output
cd ..
cd linux
mkdir -p games
mkdir -p data
mkdir -p wads
mkdir -p output
rm -f ap-gen-tool-linux.zip
zip ap-gen-tool-linux.zip ap_gen_tool.sh ap_gen_tool.x86_64 ap_gen_tool.pck games data wads output
cd ..

