export interface Product {
  id: string
  name: string
  category: string
  description: string
  price_cents: number
  image_url: string
  image_alt: string
  accent: string
  badge?: string | null
}

export interface DiscountQuote {
  code: string
  valid: boolean
  discount_percent: number
  discount_cents: number
  message: string
}

export interface CheckoutRequest {
  email: string
  items: Array<{ product_id: string; quantity: number }>
  discount_code?: string
}

export interface CheckoutResponse {
  order_id: string
  status: 'confirmed'
  email: string
  totals: {
    subtotal_cents: number
    discount_cents: number
    shipping_cents: number
    total_cents: number
  }
  message: string
}