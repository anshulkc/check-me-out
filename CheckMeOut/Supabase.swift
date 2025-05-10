//
//  Supabase.swift
//  CheckMeOut
//
//  Created by Anshul Chennavaram on 5/9/25.
//

import Foundation
import Supabase


let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://hibmwhxkbrzuygnojtyb.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhpYm13aHhrYnJ6dXlnbm9qdHliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY3NTUyNjUsImV4cCI6MjA2MjMzMTI2NX0.IV4JujAlWuKQqssJ-awzoymsNLshR6fPwYcKHpkR-O8"
)
