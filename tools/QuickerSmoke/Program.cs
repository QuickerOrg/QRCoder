using System;
using System.Buffers.Binary;
using System.IO;
using System.Reflection.PortableExecutable;
using QRCoder;

using (var stream = File.OpenRead(typeof(QRCodeGenerator).Assembly.Location))
using (var pe = new PEReader(stream))
{
    var flags = pe.PEHeaders.CorHeader?.Flags ?? 0;
    if (pe.PEHeaders.CoffHeader.Machine != Machine.I386 || (flags & CorFlags.ILOnly) == 0 ||
        (flags & (CorFlags.Requires32Bit | CorFlags.Prefers32Bit)) != 0)
        throw new InvalidDataException("QRCoder assembly must be AnyCPU IL.");
}

using var generator = new QRCodeGenerator();
using var qr = generator.CreateQrCode("Quicker AnyCPU x64 ARM64 中文", QRCodeGenerator.ECCLevel.Q);
using var renderer = new PngByteQRCode(qr);
var png = renderer.GetGraphic(4);
var signature = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 };
if (png.Length < 33 || !png.AsSpan(0, 8).SequenceEqual(signature))
    throw new InvalidDataException("QR renderer did not produce a PNG.");
var width = BinaryPrimitives.ReadInt32BigEndian(png.AsSpan(16, 4));
var height = BinaryPrimitives.ReadInt32BigEndian(png.AsSpan(20, 4));
if (width != qr.ModuleMatrix.Count * 4 || width != height)
    throw new InvalidDataException("PNG dimensions differ from the QR module matrix.");
Console.WriteLine($"PASS AnyCPU assembly and QR PNG: {width}x{height}, {png.Length} bytes.");
