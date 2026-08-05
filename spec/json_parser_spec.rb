RSpec.describe Ruby2D::JsonParser do
  def parse(s) = described_class.parse(s)

  it 'parses null, true, false' do
    expect(parse('null')).to be_nil
    expect(parse('true')).to be true
    expect(parse('false')).to be false
  end

  it 'parses integers' do
    expect(parse('0')).to eq(0)
    expect(parse('42')).to eq(42)
    expect(parse('-7')).to eq(-7)
  end

  it 'parses floats and exponents' do
    expect(parse('3.14')).to eq(3.14)
    expect(parse('-0.5')).to eq(-0.5)
    expect(parse('1e3')).to eq(1000.0)
    expect(parse('2.5E-2')).to eq(0.025)
    expect(parse('1.5e+2')).to eq(150.0)
  end

  it 'parses strings, including escapes' do
    expect(parse('"hello"')).to eq('hello')
    expect(parse('""')).to eq('')
    expect(parse('"line\\nbreak"')).to eq("line\nbreak")
    expect(parse('"\\"quoted\\""')).to eq('"quoted"')
    expect(parse('"slash\\/path"')).to eq('slash/path')
    expect(parse('"\\b\\f\\r\\t"')).to eq("\b\f\r\t")
  end

  it 'parses unicode escapes (BMP)' do
    expect(parse('"\\u00e9"')).to eq('é')
    expect(parse('"\\u4e2d"')).to eq('中')
  end

  it 'parses surrogate pairs (astral)' do
    # U+1F600 GRINNING FACE encoded as 😀
    expect(parse('"\\uD83D\\uDE00"').bytes).to eq("\u{1F600}".bytes)
  end

  it 'parses arrays' do
    expect(parse('[]')).to eq([])
    expect(parse('[1, 2, 3]')).to eq([1, 2, 3])
    expect(parse('[true, null, "x"]')).to eq([true, nil, 'x'])
    expect(parse('[[1, 2], [3, 4]]')).to eq([[1, 2], [3, 4]])
  end

  it 'parses objects' do
    expect(parse('{}')).to eq({})
    expect(parse('{"a": 1, "b": 2}')).to eq({ 'a' => 1, 'b' => 2 })
    expect(parse('{"nested": {"k": "v"}}')).to eq({ 'nested' => { 'k' => 'v' } })
  end

  it 'tolerates whitespace and newlines' do
    s = "  {\n  \"k\" : 1 ,\n  \"a\" : [\n 1, 2\n]\n}\n"
    expect(parse(s)).to eq({ 'k' => 1, 'a' => [1, 2] })
  end

  it 'raises ParseError on trailing data' do
    expect { parse('1 2') }.to raise_error(described_class::ParseError)
  end

  it 'raises ParseError on unterminated string' do
    expect { parse('"oops') }.to raise_error(described_class::ParseError)
  end

  it 'raises ParseError on bad number' do
    expect { parse('1.') }.to raise_error(described_class::ParseError)
    expect { parse('1e') }.to raise_error(described_class::ParseError)
  end

  it 'raises ParseError on bad object syntax' do
    expect { parse('{"a" 1}') }.to raise_error(described_class::ParseError)
    expect { parse('{1: 2}') }.to raise_error(described_class::ParseError)
  end

  it 'raises ParseError on bad escape' do
    expect { parse('"\\q"') }.to raise_error(described_class::ParseError)
    expect { parse('"\\u12"') }.to raise_error(described_class::ParseError)
  end

  it 'raises ParseError on a lone low surrogate (not a RangeError)' do
    expect { parse('"\\uDC00"') }.to raise_error(described_class::ParseError)
  end

  it 'raises ParseError (not SystemStackError) on deeply nested input' do
    expect { parse('[' * 1000) }.to raise_error(described_class::ParseError)
  end
end
