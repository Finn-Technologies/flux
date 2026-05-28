package com.finn.flux

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class FluxWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val title = widgetData.getString("creationTitle", "Flux Creation")
                val colorHex = widgetData.getString("creationColor", "#FF8FAB")
                val subtitle = widgetData.getString("content", "Tap to open")
                val screenshotPath = widgetData.getString("screenshotPath", null)

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_subtitle, subtitle)

                val hasScreenshot = !screenshotPath.isNullOrEmpty() && File(screenshotPath).exists()

                if (hasScreenshot) {
                    val bitmap = BitmapFactory.decodeFile(screenshotPath)
                    if (bitmap != null) {
                        setImageViewBitmap(R.id.widget_screenshot, bitmap)
                        setViewVisibility(R.id.widget_screenshot, View.VISIBLE)
                        setViewVisibility(R.id.widget_card, View.GONE)
                    } else {
                        applyCardStyle(this, colorHex)
                    }
                } else {
                    applyCardStyle(this, colorHex)
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun applyCardStyle(views: RemoteViews, colorHex: String) {
        views.setViewVisibility(R.id.widget_screenshot, View.GONE)
        views.setViewVisibility(R.id.widget_card, View.VISIBLE)
        try {
            val bgColor = Color.parseColor(colorHex)
            views.setInt(R.id.widget_card, "setBackgroundColor", bgColor)
        } catch (e: Exception) {
            views.setInt(R.id.widget_card, "setBackgroundColor", Color.parseColor("#FF8FAB"))
        }
    }
}
