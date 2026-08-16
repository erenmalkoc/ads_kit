/// Our own banner size vocabulary. Provider packages translate this into
/// whatever size type their SDK expects — this type never crosses into a
/// provider's SDK call unconverted.
enum AdBannerSize {
  banner,
  largeBanner,
  mediumRectangle,
  adaptive,
}
