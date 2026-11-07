const SUPABASE_URL = (
  import.meta.env.VITE_SUPABASE_URL ||
  import.meta.env.NEXT_PUBLIC_SUPABASE_URL ||
  ""
).replace(/\/$/, "");
const SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  import.meta.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
  "";
const TABLE = "iclearer_downloads";

const REST = SUPABASE_URL ? `${SUPABASE_URL}/rest/v1/${TABLE}` : "";

const supabaseHeaders = {
  apikey: SUPABASE_ANON_KEY,
  Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
  Accept: "application/json",
  "Content-Type": "application/json",
};

export type IclearerLead = {
  name?: string;
  email?: string;
  feedback?: string;
};

export type IclearerFeedback = {
  name: string;
  text: string;
  createdAt?: string;
};

const asTotal = (value: unknown): number | null => {
  const total = Number(value);
  return Number.isFinite(total) && total >= 0 ? total : null;
};

const totalFromContentRange = (response: Response): number | null => {
  const range = response.headers.get("content-range");
  if (!range) return null;
  const total = range.split("/")[1];
  if (!total || total === "*") return null;
  return asTotal(total);
};

const clean = (value?: string) => value?.trim() || "";

const configured = () => Boolean(SUPABASE_URL && SUPABASE_ANON_KEY);

async function insertRow(lead?: IclearerLead): Promise<boolean> {
  if (!configured()) return false;
  const created_at = new Date().toISOString();
  const full: Record<string, string> = { created_at };
  const name = clean(lead?.name);
  const email = clean(lead?.email);
  const feedback = clean(lead?.feedback);
  if (name) full.name = name;
  if (email) full.email = email;
  if (feedback) full.feedback = feedback;

  const recorded = await fetch(REST, {
    method: "POST",
    headers: {
      ...supabaseHeaders,
      Prefer: "return=minimal",
    },
    body: JSON.stringify(full),
  });
  return recorded.ok;
}

async function fetchSharedCount(): Promise<number | null> {
  if (!configured()) return null;
  const counted = await fetch(`${REST}?select=id&feedback=is.null`, {
    headers: {
      ...supabaseHeaders,
      Prefer: "count=exact",
      Range: "0-0",
    },
  });
  if (counted.ok) {
    const fromHeader = totalFromContentRange(counted);
    if (fromHeader != null) return fromHeader;
  }

  const listed = await fetch(`${REST}?select=id&feedback=is.null`, {
    headers: supabaseHeaders,
  });
  if (!listed.ok) return null;
  const rows = await listed.json();
  return Array.isArray(rows) ? rows.length : null;
}

export async function getSharedDownloadCount(): Promise<number | null> {
  try {
    return await fetchSharedCount();
  } catch {
    return null;
  }
}

export async function bumpSharedDownloadCount(
  lead?: IclearerLead
): Promise<number | null> {
  try {
    const ok = await insertRow(lead);
    if (!ok) return null;
    return await fetchSharedCount();
  } catch {
    return null;
  }
}

export async function submitIclearerFeedback(
  lead: Required<Pick<IclearerLead, "name" | "email" | "feedback">>
): Promise<boolean> {
  try {
    return await insertRow({
      name: lead.name,
      email: lead.email,
      feedback: lead.feedback,
    });
  } catch {
    return false;
  }
}

export async function fetchIclearerFeedback(): Promise<IclearerFeedback[]> {
  if (!configured()) return [];
  try {
    const response = await fetch(
      `${REST}?select=name,feedback,created_at&feedback=not.is.null&order=created_at.desc&limit=48`,
      { headers: supabaseHeaders }
    );
    if (!response.ok) return [];
    const rows = await response.json();
    if (!Array.isArray(rows)) return [];
    return rows
      .map((row) => {
        const text = clean(row?.feedback);
        const name = clean(row?.name) || "Anonymous";
        if (!text) return null;
        return {
          name,
          text,
          createdAt: typeof row?.created_at === "string" ? row.created_at : undefined,
        } satisfies IclearerFeedback;
      })
      .filter((item): item is IclearerFeedback => item != null);
  } catch {
    return [];
  }
}
