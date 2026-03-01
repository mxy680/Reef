//
//  Supabase.swift
//  Reef
//
//  Supabase client singleton
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://YOUR_PROJECT_REF.supabase.co")!,
    supabaseKey: "YOUR_ANON_KEY"
)
