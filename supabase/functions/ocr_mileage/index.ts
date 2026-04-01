Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': '*',
      },
    })
  }

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': 'application/json',
  }

  try {
    const { imageBase64, mediaType } = await req.json()

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'ANTHROPIC_API_KEY not set' }),
        { status: 500, headers: corsHeaders }
      )
    }

    // 미디어 타입 자동 감지
    let detectedType = mediaType ?? 'image/jpeg'
    if (!mediaType) {
      const prefix = imageBase64.substring(0, 16)
      if (prefix.startsWith('iVBORw'))  detectedType = 'image/png'
      else if (prefix.startsWith('/9j/')) detectedType = 'image/jpeg'
      else if (prefix.startsWith('R0lGOD')) detectedType = 'image/gif'
      else if (prefix.startsWith('UklGR')) detectedType = 'image/webp'
    }

    console.log(`[OCR] mediaType: ${detectedType}, base64 length: ${imageBase64.length}`)

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-opus-4-5',
        max_tokens: 64,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: detectedType,
                  data: imageBase64,
                },
              },
              {
                type: 'text',
                text: `이미지에서 숫자를 찾아 읽으세요.

규칙:
- 숫자만 정수로 답하세요 (예: 12345)
- 소수점·쉼표·공백·단위(kg,m,원 등)는 모두 제거하세요
- 여러 숫자가 있으면 가장 크거나 중심에 있는 숫자 하나만
- 숫자가 없거나 읽을 수 없으면 UNKNOWN
- 다른 설명 없이 숫자 또는 UNKNOWN만 출력`,
              },
            ],
          },
          {
            // prefill로 불필요한 앞말 차단
            role: 'assistant',
            content: '',
          },
        ],
      }),
    })

    const data = await res.json()
    console.log('[OCR] anthropic response:', JSON.stringify(data))

    const raw  = (data.content?.[0]?.text ?? 'UNKNOWN').trim()
    // 숫자만 추출 (혹시 단위 등 붙어있으면 제거)
    const match = raw.match(/\d+/)
    const text  = match ? match[0] : 'UNKNOWN'

    return new Response(
      JSON.stringify({ text, detectedType }),
      { headers: corsHeaders }
    )
  } catch (e) {
    console.error('[OCR] error:', e)
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: corsHeaders }
    )
  }
})