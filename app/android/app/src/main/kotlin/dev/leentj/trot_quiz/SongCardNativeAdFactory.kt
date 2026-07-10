package dev.leentj.trot_quiz

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
        val cta = adView.findViewById<TextView>(R.id.ad_cta)
        val icon = adView.findViewById<ImageView>(R.id.ad_icon)

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

        val ctaText = nativeAd.callToAction
        if (ctaText.isNullOrEmpty()) {
            cta.visibility = View.GONE
        } else {
            cta.visibility = View.VISIBLE
            cta.text = ctaText
        }
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
