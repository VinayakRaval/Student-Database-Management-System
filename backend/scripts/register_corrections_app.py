with open("SDMS/settings.py", "r", encoding="utf-8") as f:
    text = f.read()

target = '"announcements",'
rep = '"announcements",\n    "corrections",'

if target in text and '"corrections"' not in text:
    text = text.replace(target, rep, 1)
    with open("SDMS/settings.py", "w", encoding="utf-8") as f:
        f.write(text)
    print("corrections added to settings.py")

with open("SDMS/urls.py", "r", encoding="utf-8") as f:
    text_urls = f.read()

target_urls = "path('announcements/', include('announcements.urls')),"
rep_urls = "path('announcements/', include('announcements.urls')),\n    path('corrections/', include('corrections.urls')),\n    path('api/corrections/', include('corrections.urls')),"

if target_urls in text_urls and "corrections" not in text_urls:
    text_urls = text_urls.replace(target_urls, rep_urls, 1)
    with open("SDMS/urls.py", "w", encoding="utf-8") as f:
        f.write(text_urls)
    print("corrections urls added to SDMS/urls.py")
