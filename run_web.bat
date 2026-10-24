@echo off
rem Runs CalorieKnight at http://localhost:5050 for your everyday Chrome to open.
rem "flutter run -d chrome" starts Chrome with a brand-new, throwaway profile every time, so
rem everything saved in the browser (hero, plan, progress) is gone on the next run. Serving it
rem instead and opening it in your normal Chrome keeps the save. Press r here to reload after changes.
start "" http://localhost:5050
flutter run -d web-server --web-port 5050 %*
