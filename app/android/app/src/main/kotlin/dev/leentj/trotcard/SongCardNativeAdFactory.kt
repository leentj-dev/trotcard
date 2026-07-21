package dev.leentj.trotcard

import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/** Renders a native ad using a song-row-styled layout. factoryId = "songCard". */
class SongCardNativeAdFactory(private val inflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView =
            inflater.inflate(R.layout.native_ad_song, null) as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val badge = adView.findViewById<TextView>(R.id.ad_badge)
        val cta = adView.findViewById<TextView>(R.id.ad_cta)
        val icon = adView.findViewById<ImageView>(R.id.ad_icon)

        // 리스트 행 글자색(onSurface)에 맞춰 라이트/다크로 색을 정한다.
        val dark = (customOptions?.get("dark") as? Boolean) ?: true
        val titleColor = if (dark) Color.WHITE else Color.parseColor("#FF1B1B1B")
        val subColor = if (dark) Color.parseColor("#B3FFFFFF") else Color.parseColor("#B31B1B1B")
        headline.setTextColor(titleColor)
        body.setTextColor(subColor)
        badge.setTextColor(subColor)

        headline.text = nativeAd.headline
        adView.headlineView = headline

        val bodyText = nativeAd.body
        if (bodyText.isNullOrEmpty()) {
            body.visibility = View.GONE
        } else {
            body.visibility = View.VISIBLE
            body.text = bodyText
        }
        adView.bodyView = body

        // CTA 는 클릭 등록용으로만 두고 화면엔 숨긴다(행처럼 보이게).
        cta.text = nativeAd.callToAction
        cta.visibility = View.GONE
        adView.callToActionView = cta

        val ic = nativeAd.icon
        if (ic != null) {
            icon.setImageDrawable(ic.drawable)
            icon.visibility = View.VISIBLE
        } else {
            icon.visibility = View.GONE
        }
        adView.iconView = icon

        adView.setNativeAd(nativeAd)
        return adView
    }
}
