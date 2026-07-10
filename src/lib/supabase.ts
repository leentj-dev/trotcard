import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(
  "https://mlvmpmwedliivwdxydsp.supabase.co",
  "sb_publishable_iRC8NuoW_DpDW94dmnMBaQ_TDvBZjYR",
  { db: { schema: "kh" } },
);
