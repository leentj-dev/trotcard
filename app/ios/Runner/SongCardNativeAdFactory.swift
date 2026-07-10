import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

/// Builds a native ad styled like a song list row (thumbnail + title + artist),
/// mirroring the Android `native_ad_song.xml` layout. factoryId = "songCard".
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

    // Card background: #14101B fill, #251E30 border, radius 14.
    let card = UIView()
    card.translatesAutoresizingMaskIntoConstraints = false
    card.backgroundColor = Self.hex(0x14101B)
    card.layer.cornerRadius = 14
    card.layer.borderWidth = 1
    card.layer.borderColor = Self.hex(0x251E30).cgColor
    card.clipsToBounds = true
    adView.addSubview(card)

    // Thumbnail (ad icon): 118x66, rounded 10.
    let icon = UIImageView()
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.contentMode = .scaleAspectFill
    icon.clipsToBounds = true
    icon.layer.cornerRadius = 10
    icon.backgroundColor = Self.hex(0x251E30)
    icon.image = nativeAd.icon?.image
    card.addSubview(icon)
    adView.iconView = icon

    // Headline: white bold 15, single line.
    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.textColor = .white
    headline.font = .systemFont(ofSize: 15, weight: .bold)
    headline.numberOfLines = 1
    headline.setContentHuggingPriority(.defaultLow, for: .horizontal)
    headline.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    adView.headlineView = headline

    // "광고" badge: #33FFFFFF bg, radius 4, text #CFC8DA 9 bold.
    let badge = PaddingLabel(insets: UIEdgeInsets(top: 1, left: 5, bottom: 1, right: 5))
    badge.text = "광고"
    badge.textColor = Self.hex(0xCFC8DA)
    badge.font = .systemFont(ofSize: 9, weight: .bold)
    badge.backgroundColor = UIColor.white.withAlphaComponent(0.2)
    badge.layer.cornerRadius = 4
    badge.clipsToBounds = true
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let titleRow = UIStackView(arrangedSubviews: [headline, badge])
    titleRow.axis = .horizontal
    titleRow.alignment = .center
    titleRow.spacing = 6

    // Body: #C4B5FD 12.5, single line.
    let body = UILabel()
    body.text = nativeAd.body
    body.textColor = Self.hex(0xC4B5FD)
    body.font = .systemFont(ofSize: 12.5)
    body.numberOfLines = 1
    body.isHidden = (nativeAd.body?.isEmpty ?? true)
    adView.bodyView = body

    // Call to action: #7C3AED bg, radius 8, white bold 12. Non-tappable itself —
    // the GADNativeAdView handles the tap.
    let cta = PaddingLabel(insets: UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12))
    cta.text = nativeAd.callToAction
    cta.textColor = .white
    cta.font = .systemFont(ofSize: 12, weight: .bold)
    cta.backgroundColor = Self.hex(0x7C3AED)
    cta.layer.cornerRadius = 8
    cta.clipsToBounds = true
    cta.isHidden = (nativeAd.callToAction?.isEmpty ?? true)
    cta.isUserInteractionEnabled = false
    adView.callToActionView = cta

    let ctaRow = UIStackView(arrangedSubviews: [cta, UIView()])
    ctaRow.axis = .horizontal

    let column = UIStackView(arrangedSubviews: [titleRow, body, ctaRow])
    column.axis = .vertical
    column.alignment = .fill
    column.spacing = 3
    column.setCustomSpacing(7, after: body)
    column.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(column)

    NSLayoutConstraint.activate([
      card.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      card.topAnchor.constraint(equalTo: adView.topAnchor),
      card.bottomAnchor.constraint(equalTo: adView.bottomAnchor),

      icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
      icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 118),
      icon.heightAnchor.constraint(equalToConstant: 66),

      column.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
      column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
      column.centerYAnchor.constraint(equalTo: card.centerYAnchor),
      column.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 8),
    ])

    adView.nativeAd = nativeAd
    return adView
  }
}

/// UILabel with content insets, used for the badge and CTA pills.
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
