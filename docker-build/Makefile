all: luvi-native luvi-i386 luvi-arm32v7 luvi-arm64v8 luvi-alpine-native luvi-alpine-i386 luvi-alpine-arm32v7 luvi-alpine-arm64v8

luvi-alpine-native:
	docker build . -f Dockerfile.alpine.native -t luvi-alpine-native
	docker run --rm luvi-alpine-native cat /luvi/build/luvi > luvi-alpine-native
	chmod +x luvi-alpine-native

luvi-alpine-i386:
	docker build . -f Dockerfile.alpine.i386 -t luvi-alpine-i386
	docker run --rm luvi-alpine-i386 cat /luvi/build/luvi > luvi-alpine-i386
	chmod +x luvi-alpine-i386

luvi-alpine-arm32v6:
	docker build . -f Dockerfile.alpine.arm32v6 -t luvi-alpine-arm32v6
	docker run --rm luvi-alpine-arm32v6 cat /luvi/build/luvi > luvi-alpine-arm32v6
	chmod +x luvi-alpine-arm32v6

luvi-alpine-arm64v8:
	docker build . -f Dockerfile.alpine.arm64v8 -t luvi-alpine-arm64v8
	docker run --rm luvi-alpine-arm64v8 cat /luvi/build/luvi > luvi-alpine-arm64v8
	chmod +x luvi-alpine-arm64v8

luvi-native:
	docker build . -f Dockerfile.native -t luvi-native
	docker run --rm luvi-native cat /luvi/build/luvi > luvi-native
	chmod +x luvi-native

luvi-i386:
	docker build . -f Dockerfile.i386 -t luvi-i386
	docker run --rm luvi-i386 cat /luvi/build/luvi > luvi-i386
	chmod +x luvi-i386

luvi-arm32v7:
	docker build . -f Dockerfile.arm32v7 -t luvi-arm32v7
	docker run --rm luvi-arm32v7 cat /luvi/build/luvi > luvi-arm32v7
	chmod +x luvi-arm32v7

luvi-arm64v8:
	docker build . -f Dockerfile.arm64v8 -t luvi-arm64v8
	docker run --rm luvi-arm64v8 cat /luvi/build/luvi > luvi-arm64v8
	chmod +x luvi-arm64v8
