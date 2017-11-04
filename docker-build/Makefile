all: luvi-native luvi-i386 luvi-arm32v7 luvi-arm64v8
	
luvi-native:
	docker build . -f Dockerfile -t luvi-native

luvi-i386:
	docker build . -f Dockerfile.i386 -t luvi-i386

luvi-arm32v7:
	docker build . -f Dockerfile.arm32v7 -t luvi-arm32v7

luvi-arm64v8:
	docker build . -f Dockerfile.arm64v8 -t luvi-arm64v8
