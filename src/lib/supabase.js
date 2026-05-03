import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  'https://xfrzdyloocdfipfzmwge.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhmcnpkeWxvb2NkZmlwZnptd2dlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1MTcyMzgsImV4cCI6MjA5MzA5MzIzOH0.fWuwS-QTXszYhFnUqH3GH9p_OhwTwY_0ZBdmMfQ8SAw'
)
