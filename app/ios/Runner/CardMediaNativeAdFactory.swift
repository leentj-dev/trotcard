import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

/// "Pretty card" native ad for the between-cards pager — big media + icon /
/// headline / body + green CTA in the app's maroon tone. Mirrors the Android
/// `native_ad_card_media.xml`. factoryId = "cardMedia".
class CardMediaNativeAdFactory: NSObject, FLTNativeAdFactory {

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

    // Maroon card.
    let card = UIView()
    card.translatesAutoresizingMaskIntoConstraints = false
    card.backgroundColor = Self.hex(0x241019)
    card.layer.cornerRadius = 20
    card.clipsToBounds = true
    adView.addSubview(card)

    // Media.
    let media = GADMediaView()
    media.translatesAutoresizingMaskIntoConstraints = false
    media.contentMode = .scaleAspectFill
    media.clipsToBounds = true
    media.mediaContent = nativeAd.mediaContent
    adView.mediaView = media

    // Icon.
    let icon = UIImageView()
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.contentMode = .scaleAspectFill
    icon.clipsToBounds = true
    icon.layer.cornerRadius = 10
    icon.backgroundColor = Self.hex(0x251E30)
    icon.image = nativeAd.icon?.image
    icon.isHidden = (nativeAd.icon?.image == nil)
    adView.iconView = icon

    // Headline.
    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.textColor = .white
    headline.font = .systemFont(ofSize: 18, weight: .bold)
    headline.numberOfLines = 1
    headline.setContentHuggingPriority(.defaultLow, for: .horizontal)
    headline.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    adView.headlineView = headline

    // "광고" badge.
    let badge = PaddingLabel(insets: UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
    badge.text = "광고"
    badge.textColor = Self.hex(0xCFC8DA)
    badge.font = .systemFont(ofSize: 10, weight: .bold)
    badge.backgroundColor = UIColor.white.withAlphaComponent(0.2)
    badge.layer.cornerRadius = 4
    badge.clipsToBounds = true
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let titleRow = UIStackView(arrangedSubviews: [headline, badge])
    titleRow.axis = .horizontal
    titleRow.alignment = .center
    titleRow.spacing = 6

    // Body.
    let body = UILabel()
    body.text = nativeAd.body
    body.textColor = UIColor.white.withAlphaComponent(0.75)
    body.font = .systemFont(ofSize: 14)
    body.numberOfLines = 2
    body.isHidden = (nativeAd.body?.isEmpty ?? true)
    adView.bodyView = body

    let textColumn = UIStackView(arrangedSubviews: [titleRow, body])
    textColumn.axis = .vertical
    textColumn.alignment = .fill
    textColumn.spacing = 3

    let infoRow = UIStackView(arrangedSubviews: [icon, textColumn])
    infoRow.axis = .horizontal
    infoRow.alignment = .center
    infoRow.spacing = 10
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 44),
      icon.heightAnchor.constraint(equalToConstant: 44),
    ])

    // CTA button (green pill, full width).
    let cta = PaddingLabel(insets: UIEdgeInsets(top: 13, left: 12, bottom: 13, right: 12))
    cta.text = nativeAd.callToAction
    cta.textColor = .white
    cta.font = .systemFont(ofSize: 16, weight: .bold)
    cta.textAlignment = .center
    cta.backgroundColor = Self.hex(0x00704A)
    cta.layer.cornerRadius = 12
    cta.clipsToBounds = true
    cta.isUserInteractionEnabled = false
    cta.isHidden = (nativeAd.callToAction?.isEmpty ?? true)
    adView.callToActionView = cta

    let column = UIStackView(arrangedSubviews: [media, infoRow, cta])
    column.axis = .vertical
    column.alignment = .fill
    column.spacing = 12
    column.isLayoutMarginsRelativeArrangement = true
    column.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 14, right: 14)
    column.setCustomSpacing(0, after: media)  // media hugs the top edge
    column.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(column)

    NSLayoutConstraint.activate([
      card.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      card.topAnchor.constraint(equalTo: adView.topAnchor),
      card.bottomAnchor.constraint(equalTo: adView.bottomAnchor),

      column.leadingAnchor.constraint(equalTo: card.leadingAnchor),
      column.trailingAnchor.constraint(equalTo: card.trailingAnchor),
      column.topAnchor.constraint(equalTo: card.topAnchor),
      column.bottomAnchor.constraint(equalTo: card.bottomAnchor),

      media.heightAnchor.constraint(equalToConstant: 180),
    ])

    // Top padding for the info row (media has 0 spacing after it).
    infoRow.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
    infoRow.isLayoutMarginsRelativeArrangement = true

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
