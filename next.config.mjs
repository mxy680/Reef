/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false, // Required for Framer animations
  transpilePackages: ["unframer"],
  devIndicators: false,
  webpack: (config) => {
    config.watchOptions = {
      aggregateTimeout: 300,
      poll: 1000,
      ignored: /node_modules/,
    }
    return config
  },
}

export default nextConfig
