package com.finn.flux

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

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

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_subtitle, subtitle)

                try {
                    val bgColor = Color.parseColor(colorHex)
                    setInt(R.id.widget_card, "setBackgroundColor", bgColor)
                } catch (e: Exception) {
                    setInt(R.id.widget_card, "setBackgroundColor", Color.parseColor("#FF8FAB"))
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
