

build:
	rm -rf ./docs
	./hugo -d docs >> build.log
	@cp ./googlec03aeb90afb546ce.html ./docs
	@echo "blog.golang.space" > ./docs/CNAME
	@echo -e "打包完成"

push:
	git add .
	git commit -m "$(m)" >> build.log
	echo "正在发送到服务器..."
	git push 
	@echo "OK"

