cd "${0%/*}"
rm -f ap-gen-tool-windows.zip
cd windows
mkdir -p games
mkdir -p data
mkdir -p wads
mkdir -p output
rm -f ap-gen-tool-windows.zip
zip ap-gen-tool-windows.zip ap_gen_tool.exe ap_gen_tool.pck games data wads output
mv ap-gen-tool-windows.zip ..

