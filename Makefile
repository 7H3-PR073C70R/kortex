init:
	(echo "API_BASE_URL=https://example.com"  >> .env.development; echo "API_BASE_URL=https://example.com" >> .env.production; echo "API_BASE_URL=https://example.com"  >> .env.staging; flutter clean; flutter pub get; dart run build_runner build -d)

get:
	(flutter pub get)

fresh:
	(rm pubspec.lock; flutter clean; flutter pub get; dart run build_runner build -d)

runner:
	(dart run build_runner build -d)

watch:
	(dart run build_runner watch -d)

apk:
	(flutter build apk --flavor production --target lib/main_production.dart --release)

mac_bundle:
	(flutter build macos --release --flavor production -t lib/main_production.dart)
	
web:
	(flutter build web --release --target lib/main_production.dart)

deploy_web:
	(flutter build web --release --target lib/main_production.dart && npx firebase-tools deploy --only hosting)
	(npx firebase-tools deploy --only hosting)