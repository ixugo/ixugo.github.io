#!/bin/zsh

set -e

# 删除旧打包文件
rm -rf ./docs

# 打包
./hugo -D docs >> build.log
echo -e "\n打包完成\n"

cp ./googlec03aeb90afb546ce.html ./docs
echo "blog.golang.space" > ./docs/CNAME

git commit -m "blog" >> build.log
echo -e "\n正在发送到服务器...\n"
git push 
echo -e "任务完成"

