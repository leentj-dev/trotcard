import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

/// Builds a native ad styled like a song list row (thumbnail 176x99 + big title
/// + artist), mirroring the Android `native_ad_song.xml` layout. Text colors
/// follow the app theme passed in customOptions["dark"]. factoryId = "songCard".
class SongCardNativeAdFactory: NSObject, FLTNativeAdFactory {

  private static func hex(_ value: UInt32, alpha: CGFloat = 1) -> UIColor {
    UIColor(
      red: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: alpha)
  }

  func createNativeAd(
    _ nativeAd: GADNativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> GADNativeAdView? {
    let adView = GADNativeAdView()
    adView.translatesAutoresizingMaskIntoConstraints = false

    // 리스트 행 글자색(onSurface)에 맞춰 라이트/다크 색 결정.
    let dark = (customOptions?["dark"] as? Bool) ?? true
    let titleColor: UIColor = dark ? .white : Self.hex(0x1B1B1B)
    let subColor: UIColor = dark ? UIColor.white.withAlphaComponent(0.7)
      : Self.hex(0x1B1B1B, alpha: 0.7)

    // Transparent container — no card, reads like a song row.
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.backgroundColor = .clear
    adView.addSubview(container)

    // Thumbnail (ad icon): 176x99, rounded 12 — same as the song row.
    let icon = UIImageView()
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.contentMode = .scaleAspectFill
    icon.clipsToBounds = true
    icon.layer.cornerRadius = 12
    icon.backgroundColor = Self.hex(0x251E30)
    icon.image = nativeAd.icon?.image
    container.addSubview(icon)
    adView.iconView = icon

    // Headline: bold, theme color, up to 2 lines.
    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.textColor = titleColor
    headline.font = .systemFont(ofSize: 17, weight: .bold)
    headline.numberOfLines = 2
    headline.setContentHuggingPriority(.defaultLow, for: .horizontal)
    headline.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    adView.headlineView = headline

    // "광고" badge: subtle pill so the ad stays distinguishable (policy).
    let badge = PaddingLabel(insets: UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
    badge.text = "광고"
    badge.textColor = subColor
    badge.font = .systemFont(ofSize: 10, weight: .bold)
    badge.backgroundColor = (dark ? UIColor.white : UIColor.black).withAlphaComponent(0.12)
    badge.layer.cornerRadius = 4
    badge.clipsToBounds = true
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let titleRow = UIStackView(arrangedSubviews: [headline, badge])
    titleRow.axis = .horizontal
    titleRow.alignment = .center
    titleRow.spacing = 6

    // Body (advertiser / store), like the artist line.
    let body = UILabel()
    body.text = nativeAd.body
    body.textColor = subColor
    body.font = .systemFont(ofSize: 14, weight: .semibold)
    body.numberOfLines = 1
    body.isHidden = (nativeAd.body?.isEmpty ?? true)
    adView.bodyView = body

    // CTA registered for clicks but hidden, so the ad reads like a song row.
    let cta = UILabel()
    cta.text = nativeAd.callToAction
    cta.isHidden = true
    cta.isUserInteractionEnabled = false
    adView.callToActionView = cta

    let column = UIStackView(arrangedSubviews: [titleRow, body])
    column.axis = .vertical
    column.alignment = .fill
    column.spacing = 6
    column.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(column)

    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 4),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -4),
      container.topAnchor.constraint(equalTo: adView.topAnchor),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor),

      icon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 120),
      icon.heightAnchor.constraint(equalToConstant: 68),

      column.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
      column.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      column.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      column.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 8),
    ])

    adView.nativeAd = nativeAd
    return adView
  }
}

/// UILabel with content insets, used for the badge pill.
private class PaddingLabel: UILabel {
  private let insets: UIEdgeInsets
  init(insets: UIEdgeInsets) {
    self.insets = insets
    super.init(frame: .zero)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: insets))
  }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(
      width: size.width + insets.left + insets.right,
      height: size.height + insets.top + insets.bottom)
  }
}
