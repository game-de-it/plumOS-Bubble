# Scraping artwork

Connect to Wi-Fi, then open `START` → `Apps` → `Scraping`. Select the target
systems and follow the prompts. Results are stored in the SD1 image area used by
the frontend.

- Conventional release-style ROM names improve matching.
- Do not power off or disable Wi-Fi during a scrape.
- Refresh the list or restart the frontend if new images are not visible.
- On failure, check free space, time, Wi-Fi and DNS, then inspect `plumos/logs/`.

Artwork and scrape state remain on SD1 even when the ROM itself is on SD2.
