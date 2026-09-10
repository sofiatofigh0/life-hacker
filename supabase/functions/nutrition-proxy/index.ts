import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const headers = { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" };
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  const apiKey = Deno.env.get("USDA_API_KEY");
  if (!apiKey) return new Response(JSON.stringify({ error: "USDA_API_KEY is not configured" }), { status: 500, headers });
  const url = new URL(request.url);
  const isSearch = url.pathname.endsWith("/search");
  const isBarcode = url.pathname.endsWith("/barcode");
  if (!isSearch && !isBarcode) return new Response(JSON.stringify({ error: "Not found" }), { status: 404, headers });

  // /barcode?code=… looks the GTIN/UPC up in USDA's branded-foods data. USDA
  // stores codes with varying leading zeros, so compare with them stripped.
  const code = url.searchParams.get("code")?.replace(/\D/g, "") ?? "";
  const query = isBarcode ? code : url.searchParams.get("q")?.trim();
  if (!query) return new Response(JSON.stringify([]), { headers });
  const params: Record<string, string> = { api_key: apiKey, query, pageSize: "25" };
  if (isBarcode) params.dataType = "Branded";
  const upstream = await fetch("https://api.nal.usda.gov/fdc/v1/foods/search?" + new URLSearchParams(params));
  if (!upstream.ok) return new Response(JSON.stringify({ error: "Nutrition provider unavailable" }), { status: 502, headers });
  const payload = await upstream.json();
  const nutrient = (food: any, number: string) => food.foodNutrients?.find((n: any) => n.nutrientNumber === number)?.value ?? 0;
  const stripZeros = (s: string) => s.replace(/^0+/, "");
  const foods = (payload.foods ?? []).filter((food: any) => !isBarcode || stripZeros(String(food.gtinUpc ?? "")) === stripZeros(code));
  const normalized = foods.map((food: any) => ({ id: crypto.randomUUID(), name: food.description, brand: food.brandOwner ?? null, barcode: food.gtinUpc ?? null, nutrientsPer100Grams: { calories: nutrient(food, "208"), protein: nutrient(food, "203"), carbs: nutrient(food, "205"), fat: nutrient(food, "204") }, servingGrams: food.servingSizeUnit === "g" ? food.servingSize : null, isFavorite: false }));
  return new Response(JSON.stringify(normalized), { headers });
});
