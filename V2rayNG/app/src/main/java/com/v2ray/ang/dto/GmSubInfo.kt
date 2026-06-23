package com.v2ray.ang.dto

/** Ответ нашего бэкенда /sinfo/<token> — данные подписки GoodMan Net для главного экрана. */
data class GmSubInfo(
    val ok: Boolean = false,
    val account_id: String? = null,
    val account_id_pretty: String? = null,
    val active: Boolean = false,
    val expires_at: String? = null,
    val devices_used: Int = 0,
    val devices_limit: Int = 1,
    val plus_used: Long = 0,
    val plus_limit: Long = 0
)
