/// Formats a past [DateTime] as a short relative string ("2h ago",
/// "Yesterday", "3d ago"), matching the style of the app's existing seed
/// data (`FakeSiteRepository`) so real and fake data read consistently.
String formatRelativeTime(DateTime? time) {
  if (time == null) return '—';

  final diff = DateTime.now().difference(time);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}
