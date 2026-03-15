.PHONY: build run dev test tidy

BINARY := guard
CMD     := .

build:
	go build -o $(BINARY) $(CMD)

run: build
	./$(BINARY)

dev:
	go run $(CMD)

test:
	go test ./...

tidy:
	go mod tidy
