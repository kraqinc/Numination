package com.wren.ide.data.supabase

import com.wren.ide.BuildConfig
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.ExternalAuthAction
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.createSupabaseClient

object WrenSupabase {

    val client: SupabaseClient by lazy {

        val url =
            BuildConfig
                .SUPABASE_URL
                .trim()

        val key =
            BuildConfig
                .SUPABASE_PUBLISHABLE_KEY
                .trim()

        require(
            url.isNotEmpty()
        ) {
            "SUPABASE_URL no esta configurada"
        }

        require(
            key.isNotEmpty()
        ) {
            "SUPABASE_PUBLISHABLE_KEY no esta configurada"
        }

        createSupabaseClient(
            supabaseUrl = url,
            supabaseKey = key
        ) {

            install(
                io.github.jan.supabase.auth.Auth
            ) {

                scheme = "numination"

                host = "auth"

                flowType =
                    FlowType.PKCE

                alwaysAutoRefresh = true

                autoLoadFromStorage = true

                autoSaveToStorage = true

                enableLifecycleCallbacks = true

                defaultExternalAuthAction =
                    ExternalAuthAction.CustomTabs()
            }
        }
    }

    val auth
        get() = client.auth
}
