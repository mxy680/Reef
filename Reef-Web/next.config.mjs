/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false, // Required for Framer animations
  transpilePackages: ["unframer"],
  devIndicators: false,
}

export default nextConfig
