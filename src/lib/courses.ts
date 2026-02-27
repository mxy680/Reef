import { createClient } from "./supabase/client"

export interface Course {
  id: string
  user_id: string
  name: string
  emoji: string
  color: string
  created_at: string
  updated_at: string
}

export type CourseInsert = Pick<Course, "name"> & Partial<Pick<Course, "emoji" | "color">>
export type CourseUpdate = Partial<Pick<Course, "name" | "emoji" | "color">>

export async function listCourses(): Promise<Course[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("courses")
    .select("*")
    .order("created_at", { ascending: false })

  if (error) throw error
  return data as Course[]
}

export async function createCourse(input: CourseInsert): Promise<Course> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error("Not authenticated")

  const { data, error } = await supabase
    .from("courses")
    .insert({ ...input, user_id: user.id })
    .select()
    .single()

  if (error) throw error
  return data as Course
}

export async function updateCourse(id: string, input: CourseUpdate): Promise<Course> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from("courses")
    .update(input)
    .eq("id", id)
    .select()
    .single()

  if (error) throw error
  return data as Course
}

export async function deleteCourse(id: string): Promise<void> {
  const supabase = createClient()
  const { error } = await supabase
    .from("courses")
    .delete()
    .eq("id", id)

  if (error) throw error
}
