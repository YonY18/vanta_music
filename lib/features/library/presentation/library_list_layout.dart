int songsListItemCount({
  required int trackCount,
  required bool hasNotificationBanner,
}) {
  return trackCount + (hasNotificationBanner ? 1 : 0);
}

bool isNotificationBannerIndex(int index, {required bool hasNotificationBanner}) {
  return hasNotificationBanner && index == 0;
}

int trackIndexFromSongsListIndex(
  int index, {
  required bool hasNotificationBanner,
}) {
  return hasNotificationBanner ? index - 1 : index;
}
