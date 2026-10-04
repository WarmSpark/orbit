package api

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"log"
	"math"
	"os"
	"strconv"
	"strings"
)

var jwtSecret = loadJWTSecret()

func loadJWTSecret() []byte {
	if s := strings.TrimSpace(os.Getenv("JWT_SECRET")); s != "" {
		return []byte(s)
	}
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		log.Fatalf("failed to generate a random JWT secret: %v", err)
	}
	log.Println("[security] JWT_SECRET not set — using a random per-process secret (all sessions reset on restart)")
	return []byte(hex.EncodeToString(buf))
}

var googleClientID = strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_ID"))

var allowedOrigins = parseOrigins(os.Getenv("ALLOWED_ORIGINS"))

var devAuthEnabled = strings.TrimSpace(os.Getenv("ORBIT_DEV_AUTH")) == "1"

func DevAuthEnabled() bool { return devAuthEnabled }

var prodEnv = strings.EqualFold(strings.TrimSpace(os.Getenv("ORBIT_ENV")), "production")

func IsProd() bool { return prodEnv }

func ProdConfigError() error {
	if !prodEnv {
		return nil
	}
	if devAuthEnabled {
		return errors.New("ORBIT_DEV_AUTH must not be set in production (it mints session tokens without Google)")
	}
	if googleClientID == "" {
		return errors.New("GOOGLE_CLIENT_ID is required in production so the Google token audience is enforced")
	}
	return nil
}

func parseOrigins(s string) map[string]bool {
	m := make(map[string]bool)
	for _, o := range strings.Split(s, ",") {
		if o = strings.TrimSpace(o); o != "" {
			m[o] = true
		}
	}
	return m
}

func originAllowed(origin string) bool {
	if len(allowedOrigins) == 0 {
		return true
	}
	if origin == "" {
		return true
	}
	return allowedOrigins[origin]
}

func init() {
	if prodEnv {
		log.Println("[security] ORBIT_ENV=production — dev conveniences are disabled")
	}
	if googleClientID == "" {
		log.Println("[security] GOOGLE_CLIENT_ID not set — Google token audience is NOT enforced (set it in production)")
	}
	if len(allowedOrigins) == 0 {
		log.Println("[security] ALLOWED_ORIGINS not set — all CORS/WS origins allowed (set it in production)")
	}
	if devAuthEnabled {
		log.Println("[security] ORBIT_DEV_AUTH=1 — dev login (POST /api/v1/auth/dev) is ENABLED. NEVER use this in production.")
	}
}

const (
	maxTitleLen    = 80
	maxLocationLen = 80
	maxBioLen      = 160
	maxNameLen     = 60
	maxMessageLen  = 2000
	minCapacity    = 2
	maxCapacity    = 8
)

func normalizeGender(g string) (string, bool) {
	switch strings.ToLower(strings.TrimSpace(g)) {
	case "":
		return "", true
	case "male":
		return "male", true
	case "female":
		return "female", true
	default:
		return "", false
	}
}

var allowedCategories = map[string]bool{
	"Movie":   true,
	"Canteen": true,
	"Study":   true,
	"Gaming":  true,
	"Sports":  true,
	"All":     true,
}

func normalizeCategory(c string) string {
	c = strings.TrimSpace(c)
	if c == "" || !allowedCategories[c] {
		return "All"
	}
	return c
}

var allowedAvatars = map[string]bool{
	"coral": true, "ocean": true, "forest": true, "grape": true,
	"sun": true, "rose": true, "sky": true, "mint": true,
	"default_white": true,
}

func sanitizeAvatar(a string) string {
	a = strings.ToLower(strings.TrimSpace(a))
	if allowedAvatars[a] {
		return a
	}
	return "default_white"
}

func clampCapacity(n int) int {
	if n < minCapacity {
		return minCapacity
	}
	if n > maxCapacity {
		return maxCapacity
	}
	return n
}

var blockedWords = []string{
	"kill yourself", "kys", "rape", "nude", "porn",
	"slut", "whore", "faggot", "nigger",
	"chutiya", "randi", "bhosdi", "madarchod", "behenchod",
}

func normalizeForModeration(s string) string {
	s = strings.ToLower(s)
	s = strings.NewReplacer(
		"@", "a", "$", "s", "0", "o", "1", "i", "3", "e", "!", "i",
		".", "", "_", " ", "-", " ", "*", "",
	).Replace(s)
	return strings.Join(strings.Fields(s), " ")
}

func containsBlockedContent(s string) bool {
	n := normalizeForModeration(s)
	for _, w := range blockedWords {
		if strings.Contains(n, w) {
			return true
		}
	}
	return false
}

func sanitizeText(s string, max int) string {
	s = strings.TrimSpace(s)
	s = strings.Map(func(r rune) rune {
		if r < 0x20 && r != '\n' && r != '\t' {
			return -1
		}
		return r
	}, s)
	r := []rune(s)
	if len(r) > max {
		s = strings.TrimSpace(string(r[:max]))
	}
	return s
}

func fuzzCoord(c float64) float64 {
	return math.Round(c*1000) / 1000
}

func validLatLng(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

type campusGeo struct {
	configured bool
	lat, lng   float64
	radiusKm   float64
}

var campus = loadCampus()

func loadCampus() campusGeo {
	latS := strings.TrimSpace(os.Getenv("CAMPUS_LAT"))
	lngS := strings.TrimSpace(os.Getenv("CAMPUS_LNG"))
	if latS == "" || lngS == "" {
		return campusGeo{}
	}
	lat, err1 := strconv.ParseFloat(latS, 64)
	lng, err2 := strconv.ParseFloat(lngS, 64)
	if err1 != nil || err2 != nil {
		return campusGeo{}
	}
	rad, err3 := strconv.ParseFloat(strings.TrimSpace(os.Getenv("CAMPUS_RADIUS_KM")), 64)
	if err3 != nil || rad <= 0 {
		rad = 2.0
	}
	return campusGeo{configured: true, lat: lat, lng: lng, radiusKm: rad}
}

func withinCampus(lat, lng float64) bool {
	if !campus.configured {
		return true
	}
	return haversineKm(lat, lng, campus.lat, campus.lng) <= campus.radiusKm
}

func haversineKm(lat1, lng1, lat2, lng2 float64) float64 {
	const earthR = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180
	dLng := (lng2 - lng1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	return earthR * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

const (
	ncrMinLat = 28.20
	ncrMaxLat = 29.00
	ncrMinLng = 76.70
	ncrMaxLng = 77.70
)

func withinNCR(lat, lng float64) bool {
	return lat >= ncrMinLat && lat <= ncrMaxLat && lng >= ncrMinLng && lng <= ncrMaxLng
}
