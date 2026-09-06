package main

import (
	"embed"
	"io/fs"
	"net/http"
)

//go:embed webroot
var webrootFS embed.FS

func landingHandler() http.Handler {
	sub, err := fs.Sub(webrootFS, "webroot")
	if err != nil {
		panic(err)
	}
	return http.FileServer(http.FS(sub))
}
