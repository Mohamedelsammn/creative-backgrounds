package com.backgrounds.trend4k.adblock

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log

/**
 * Best-effort inspection of **locally visible** network configuration, used to
 * tell whether something on this device is likely to be filtering the app's
 * network requests.
 *
 * ## What this deliberately is not
 *
 * Android exposes no "is an ad blocker installed" API, and there is no way to
 * prove one exists. Everything here is *evidence*, never a verdict:
 *
 *  * a VPN is extremely common for privacy, work access and geo-shifting - the
 *    overwhelming majority are not ad blockers, so a VPN alone is reported as
 *    exactly that and nothing more;
 *  * Private DNS is likewise usually a legitimate privacy choice; only
 *    hostnames belonging to well-known *filtering* resolvers are called
 *    suspicious, and even then only as a hint.
 *
 * The Flutter layer combines these signals with an actual request probe before
 * drawing any conclusion.
 *
 * ## Privacy
 *
 * Reads only: whether a VPN transport is active, and the Private DNS hostname
 * the user configured. It never inspects traffic, never enumerates installed
 * apps, never touches browsing history, and never reads DNS queries. Anything
 * unavailable is reported as unknown rather than guessed.
 */
object NetworkInterferenceProbe {

    /**
     * Hostname fragments belonging to DNS resolvers whose *stated purpose* is
     * blocking ads or trackers. Matching one is a strong hint that ad requests
     * will not complete; not matching means nothing either way.
     */
    private val FILTERING_DNS_HINTS = listOf(
        "adguard",
        "nextdns",
        "pi-hole",
        "pihole",
        "blahdns",
        "mullvad",
        "controld",
        "rethinkdns",
        "dns.adguard",
        "doh.cleanbrowsing",
        "security.cloudflare-dns", // the filtering variant, not 1.1.1.1
        "families.cloudflare-dns",
        "dns.quad9", // Quad9 filters malware/phishing by design
    )

    /**
     * Collects the signals. Every field is optional-by-nature: a value of
     * `null` means "could not determine", which callers must treat as unknown
     * rather than as a negative.
     */
    fun inspect(context: Context): Map<String, Any?> {
        val result = HashMap<String, Any?>()
        result["vpnActive"] = vpnActive(context)

        val dns = privateDnsHost(context)
        result["privateDnsHost"] = dns
        result["privateDnsFiltering"] = dns?.let { host ->
            val lower = host.lowercase()
            FILTERING_DNS_HINTS.any { lower.contains(it) }
        }
        result["sdkInt"] = Build.VERSION.SDK_INT
        return result
    }

    /**
     * Whether any active network reports the VPN transport.
     *
     * Returns null when connectivity information is unavailable, so the caller
     * can distinguish "no VPN" from "could not tell".
     */
    private fun vpnActive(context: Context): Boolean? = try {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as? ConnectivityManager
        if (cm == null) {
            null
        } else {
            // `allNetworks` is used rather than only the default network: a VPN
            // can be up and carrying this app's traffic while the default
            // network still reports Wi-Fi.
            @Suppress("DEPRECATION")
            cm.allNetworks.any { network ->
                cm.getNetworkCapabilities(network)
                    ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
            }
        }
    } catch (e: Exception) {
        Log.w(TAG, "VPN check unavailable: ${e.message}")
        null
    }

    /**
     * The user's configured Private DNS hostname, when one is set and the
     * platform exposes it (API 28+).
     *
     * Only the hostname is read - never any query made through it.
     */
    private fun privateDnsHost(context: Context): String? = try {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            null
        } else {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
                as? ConnectivityManager
            val active = cm?.activeNetwork
            val props: LinkProperties? = active?.let { cm.getLinkProperties(it) }
            props?.privateDnsServerName
        }
    } catch (e: Exception) {
        Log.w(TAG, "private DNS check unavailable: ${e.message}")
        null
    }

    private const val TAG = "AdBlockProbe"
}
