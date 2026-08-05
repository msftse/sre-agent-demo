import type { CheckoutRequest, CheckoutResponse, DiscountQuote, Product } from './types'

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? (import.meta.env.DEV ? 'http://localhost:8000' : '')

interface ApiErrorBody {
  detail?: { message?: string } | Array<{ msg?: string }>
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...init?.headers,
    },
  })

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as ApiErrorBody
    const message = Array.isArray(body.detail) ? body.detail[0]?.msg : body.detail?.message
    throw new Error(message ?? `Request failed with status ${response.status}.`)
  }

  return response.json() as Promise<T>
}

export const getProducts = () => request<Product[]>('/api/products')

export const validateDiscount = (code: string, subtotalCents: number) =>
  request<DiscountQuote>('/api/discounts/validate', {
    method: 'POST',
    body: JSON.stringify({ code, subtotal_cents: subtotalCents }),
  })

export const checkout = (payload: CheckoutRequest) =>
  request<CheckoutResponse>('/api/checkout', {
    method: 'POST',
    body: JSON.stringify(payload),
  })