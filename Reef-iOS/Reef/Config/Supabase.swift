import Foundation
import Supabase

let supabase: SupabaseClient = {
    guard
        let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
        let url = URL(string: urlString),
        let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
    else {
        fatalError("Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist — check Secrets.xcconfig")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
}()
