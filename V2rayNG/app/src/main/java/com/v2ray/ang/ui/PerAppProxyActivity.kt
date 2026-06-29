package com.v2ray.ang.ui

import android.annotation.SuppressLint
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import android.view.Menu
import android.view.MenuItem
import android.widget.Toast
import androidx.activity.viewModels
import androidx.appcompat.widget.SearchView
import androidx.lifecycle.lifecycleScope
import com.v2ray.ang.AppConfig
import com.v2ray.ang.AppConfig.ANG_PACKAGE
import com.v2ray.ang.R
import com.v2ray.ang.databinding.ActivityBypassListBinding
import com.v2ray.ang.dto.AppInfo
import com.v2ray.ang.dto.UrlContentRequest
import com.v2ray.ang.extension.toast
import com.v2ray.ang.extension.toastSuccess
import com.v2ray.ang.extension.v2RayApplication
import com.v2ray.ang.handler.MmkvManager
import com.v2ray.ang.handler.SettingsChangeManager
import com.v2ray.ang.handler.SettingsManager
import com.v2ray.ang.util.AppManagerUtil
import com.v2ray.ang.util.HttpUtil
import com.v2ray.ang.util.LogUtil
import com.v2ray.ang.util.Utils
import com.v2ray.ang.viewmodel.PerAppProxyViewModel
import es.dmoral.toasty.Toasty
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.Collator

class PerAppProxyActivity : BaseActivity() {
    private val binding by lazy { ActivityBypassListBinding.inflate(layoutInflater) }

    private var adapter: PerAppProxyAdapter? = null
    private var appsAll: List<AppInfo>? = null
    private var sortByUsage = false
    private val viewModel: PerAppProxyViewModel by viewModels()

    // Курируемый набор RU-приложений (банки/госуслуги/маркетплейсы/операторы) — идут МИМО VPN.
    private val ruPreset = listOf(
        "ru.sberbankmobile", "com.idamob.tinkoff.android", "ru.vtb24.mobilebanking.android",
        "ru.alfabank.mobile.android", "ru.gazprombank.android.mobilebank.app", "ru.raiffeisennews",
        "ru.nspk.mirpay", "ru.nspk.sbpay",
        "ru.rostel", "ru.gosuslugi.goskey", "ru.gosuslugi.app", "ru.rosreestr.mobile", "com.gnivts.selfemployed", "ru.mos.app",
        "ru.ozon.app.android", "com.wildberries.ru", "ru.beru.android", "com.avito.android",
        "ru.yandex.taxi", "ru.sbcs.store", "ru.foodfox.client", "ru.vkusvill", "ru.tander.magnit", "ru.perekrestok.app",
        "ru.yandex.yandexmaps", "ru.yandex.yandexnavi", "ru.dublgis.dgismobile",
        "ru.urentbike.app", "ru.cian.main", "ru.oneme.app",
        "ru.yandex.music", "ru.kinopoisk", "ru.yandex.disk", "ru.yandex.mail", "ru.yandex.weatherplugin",
        "ru.yandex.translate", "ru.yandex.taximeter", "ru.yandex.direct",
        "ru.mts.mymts", "ru.megafon.mlk", "ru.beeline.services", "ru.tele2.mytele2", "ru.yota.android",
        "ru.vk.store"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        //setContentView(binding.root)
        setContentViewWithToolbar(binding.root, showHomeAsUp = true, title = getString(R.string.per_app_proxy_settings))

        addCustomDividerToRecyclerView(binding.recyclerView, this, R.drawable.custom_divider)

        initList()

        binding.switchPerAppProxy.setOnCheckedChangeListener { _, isChecked ->
            MmkvManager.encodeSettings(AppConfig.PREF_PER_APP_PROXY, isChecked)
        }
        binding.switchPerAppProxy.isChecked = MmkvManager.decodeSettingsBool(AppConfig.PREF_PER_APP_PROXY, false)

        // Один ползунок: режим «обход» всегда включён — выбранные приложения идут МИМО VPN
        MmkvManager.encodeSettings(AppConfig.PREF_BYPASS_APPS, true)

        binding.switchShowSystem.setOnCheckedChangeListener { _, _ -> applyFilterSort() }

        binding.btnPresetRu.setOnClickListener {
            binding.switchPerAppProxy.isChecked = true   // включаем per-app
            viewModel.addAll(ruPreset)
            toast("RU-приложения добавлены в обход VPN")
            applyFilterSort()
        }

        binding.btnSortUsage.setOnClickListener {
            // Сортировка прямо в этом окне, без перехода в системные настройки
            sortByUsage = true
            if (!hasUsageAccess()) {
                toast("Для сортировки по частоте включите «Доступ к статистике» в настройках Android")
            }
            applyFilterSort()
        }
    }

    /** Перестраивает список: фильтр системных + сортировка (выбранные сверху, затем частота/имя). */
    private fun applyFilterSort() {
        val all = appsAll ?: return
        val showSystem = binding.switchShowSystem.isChecked
        val sel = viewModel.getAll()
        val list = all.filter { showSystem || !it.isSystemApp }
        list.forEach { it.isSelected = if (sel.contains(it.packageName)) 1 else 0 }
        val usage = if (sortByUsage) getUsageMap() else emptyMap()
        val sorted = if (sortByUsage) {
            list.sortedWith(
                compareByDescending<AppInfo> { it.isSelected }
                    .thenByDescending { usage[it.packageName] ?: 0L }
                    .thenBy { it.appName.lowercase() })
        } else {
            list.sortedWith(
                compareByDescending<AppInfo> { it.isSelected }
                    .thenBy { it.appName.lowercase() })
        }
        adapter = PerAppProxyAdapter(sorted, viewModel)
        binding.recyclerView.adapter = adapter
    }

    private fun hasUsageAccess(): Boolean = try {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        @Suppress("DEPRECATION")
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        mode == AppOpsManager.MODE_ALLOWED
    } catch (e: Exception) {
        false
    }

    private fun getUsageMap(): Map<String, Long> = try {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val begin = end - 30L * 24 * 60 * 60 * 1000
        val map = HashMap<String, Long>()
        usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, begin, end)?.forEach {
            val prev = map[it.packageName] ?: 0L
            if (it.lastTimeUsed > prev) map[it.packageName] = it.lastTimeUsed
        }
        map
    } catch (e: Exception) {
        emptyMap()
    }

    private fun initList() {
        showLoading()

        lifecycleScope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    val appsList = AppManagerUtil.loadNetworkAppList(this@PerAppProxyActivity)

                    val blacklistSet = viewModel.getAll()
                    if (blacklistSet.isNotEmpty()) {
                        appsList.forEach { app ->
                            app.isSelected = if (blacklistSet.contains(app.packageName)) 1 else 0
                        }
                        appsList.sortedWith { p1, p2 ->
                            when {
                                p1.isSelected > p2.isSelected -> -1
                                p1.isSelected < p2.isSelected -> 1
                                p1.isSystemApp > p2.isSystemApp -> 1
                                p1.isSystemApp < p2.isSystemApp -> -1
                                p1.appName.lowercase() > p2.appName.lowercase() -> 1
                                p1.appName.lowercase() < p2.appName.lowercase() -> -1
                                p1.packageName > p2.packageName -> 1
                                p1.packageName < p2.packageName -> -1
                                else -> 0
                            }
                        }
                    } else {
                        val collator = Collator.getInstance()
                        appsList.sortedWith(compareBy(collator) { it.appName })
                    }
                }

                appsAll = apps
                applyFilterSort()

            } catch (e: Exception) {
                LogUtil.e(ANG_PACKAGE, "Error loading apps", e)
            } finally {
                hideLoading()
            }
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.menu_bypass_list, menu)

        val searchItem = menu.findItem(R.id.search_view)
        if (searchItem != null) {
            val searchView = searchItem.actionView as SearchView
            searchView.setOnQueryTextListener(object : SearchView.OnQueryTextListener {
                override fun onQueryTextSubmit(query: String?): Boolean = false

                override fun onQueryTextChange(newText: String?): Boolean {
                    filterProxyApp(newText.orEmpty())
                    return false
                }
            })
        }

        return super.onCreateOptionsMenu(menu)
    }


    @SuppressLint("NotifyDataSetChanged")
    override fun onOptionsItemSelected(item: MenuItem) = when (item.itemId) {
        R.id.select_all -> {
            selectAllApp()
            allowPerAppProxy()
            true
        }

        R.id.invert_selection -> {
            invertSelection()
            allowPerAppProxy()
            true
        }

        R.id.select_proxy_app -> {
            selectProxyAppAuto()
            allowPerAppProxy()
            true
        }

        R.id.import_proxy_app -> {
            importProxyApp()
            allowPerAppProxy()
            true
        }

        R.id.export_proxy_app -> {
            exportProxyApp()
            true
        }

        else -> super.onOptionsItemSelected(item)
    }

    private fun selectAllApp() {
        adapter?.let { adapter ->
            val pkgNames = adapter.apps.map { it.packageName }
            val allSelected = pkgNames.all { viewModel.contains(it) }

            if (allSelected) {
                viewModel.removeAll(pkgNames)
            } else {
                viewModel.addAll(pkgNames)
            }
            refreshData()
        }
    }

    private fun invertSelection() {
        adapter?.let { adapter ->
            adapter.apps.forEach { app ->
                viewModel.toggle(app.packageName)
            }
            refreshData()
        }
    }

    private fun selectProxyAppAuto() {
        toast(R.string.msg_downloading_content)
        showLoading()

        val url = AppConfig.ANDROID_PACKAGE_NAME_LIST_URL
        lifecycleScope.launch(Dispatchers.IO) {
            var content = HttpUtil.getUrlContent(
                UrlContentRequest(
                    url = url,
                    timeout = 5000
                )
            )
            if (content.isNullOrEmpty()) {
                val proxyUsername = SettingsManager.getSocksUsername()
                val proxyPassword = SettingsManager.getSocksPassword()
                val httpPort = SettingsManager.getHttpPort()
                content = HttpUtil.getUrlContent(
                    UrlContentRequest(
                        url = url,
                        timeout = 5000,
                        httpPort = httpPort,
                        proxyUsername = proxyUsername,
                        proxyPassword = proxyPassword
                    )
                ) ?: ""
            }
            launch(Dispatchers.Main) {
                //LogUtil.i(AppConfig.TAG, content)
                selectProxyApp(content, true)
                toastSuccess(R.string.toast_success)
                hideLoading()
            }
        }
    }

    private fun importProxyApp() {
        val content = Utils.getClipboard(applicationContext)
        if (TextUtils.isEmpty(content)) return
        selectProxyApp(content, false)
        toastSuccess(R.string.toast_success)
    }

    private fun exportProxyApp() {
        var lst = "true"   // режим обхода всегда включён

        viewModel.getAll().forEach { pkg ->
            lst = lst + System.lineSeparator() + pkg
        }
        Utils.setClipboard(applicationContext, lst)
        toastSuccess(R.string.toast_success)
    }

    private fun allowPerAppProxy() {
        binding.switchPerAppProxy.isChecked = true
        SettingsChangeManager.makeRestartService()
    }

    @SuppressLint("NotifyDataSetChanged")
    private fun selectProxyApp(content: String, force: Boolean): Boolean {
        try {
            val proxyApps = if (TextUtils.isEmpty(content)) {
                Utils.readTextFromAssets(v2RayApplication, "proxy_package_name")
            } else {
                content
            }
            if (TextUtils.isEmpty(proxyApps)) return false

            viewModel.clear()

            if (true) {   // режим обхода всегда включён — выбранные идут мимо VPN
                adapter?.let { adapter ->
                    adapter.apps.forEach { app ->
                        val packageName = app.packageName
                        if (!inProxyApps(proxyApps, packageName, force)) {
                            viewModel.add(packageName)
                        }
                    }
                    refreshData()
                }
            } else {
                adapter?.let { adapter ->
                    adapter.apps.forEach { app ->
                        val packageName = app.packageName
                        if (inProxyApps(proxyApps, packageName, force)) {
                            viewModel.add(packageName)
                        }
                    }
                    refreshData()
                }
            }
        } catch (e: Exception) {
            LogUtil.e(AppConfig.TAG, "Error selecting proxy app", e)
            return false
        }
        return true
    }

    private fun inProxyApps(proxyApps: String, packageName: String, force: Boolean): Boolean {
        println(packageName)
        if (force) {
            if (packageName == "com.google.android.webview") return false
            if (packageName.startsWith("com.google")) return true
        }

        return proxyApps.indexOf(packageName) >= 0
    }

    private fun filterProxyApp(content: String): Boolean {
        val apps = ArrayList<AppInfo>()

        val key = content.uppercase()
        if (key.isNotEmpty()) {
            appsAll?.forEach {
                if (it.appName.uppercase().indexOf(key) >= 0
                    || it.packageName.uppercase().indexOf(key) >= 0
                ) {
                    apps.add(it)
                }
            }
        } else {
            appsAll?.forEach {
                apps.add(it)
            }
        }

        adapter = PerAppProxyAdapter(apps, adapter?.viewModel ?: viewModel)
        binding.recyclerView.adapter = adapter
        refreshData()
        return true
    }

    @SuppressLint("NotifyDataSetChanged")
    fun refreshData() {
        adapter?.notifyDataSetChanged()
    }
}
