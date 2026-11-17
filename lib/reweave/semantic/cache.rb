# frozen_string_literal: true

require "digest"
require "fileutils"
require_relative "type"

module Reweave
  module Semantic
    # Cache for semantic analysis results to avoid redundant computation
    class Cache
      def initialize(cache_dir = nil)
        @cache_dir = cache_dir || File.join(Dir.home, ".cache", "reweave", "semantic")
        FileUtils.mkdir_p(@cache_dir)
      end

      # Get cached analysis result for a project
      # Returns nil if cache is invalid or doesn't exist
      def get(project)
        cache_key = cache_key_for_project(project)
        cache_file = File.join(@cache_dir, "#{cache_key}.json")
        meta_file = File.join(@cache_dir, "#{cache_key}.meta.json")

        return nil unless File.exist?(cache_file) && File.exist?(meta_file)

        # Check if source files have changed
        meta = JSON.parse(File.read(meta_file))
        return nil unless cache_valid?(project, meta)

        # Load cached result
        data = JSON.parse(File.read(cache_file))
        reconstruct_analysis_result(data)
      end

      # Store analysis result in cache
      def set(project, result)
        cache_key = cache_key_for_project(project)
        cache_file = File.join(@cache_dir, "#{cache_key}.json")
        meta_file = File.join(@cache_dir, "#{cache_key}.meta.json")

        # Serialize result
        data = serialize_analysis_result(result)
        File.write(cache_file, JSON.pretty_generate(data))

        # Store metadata for invalidation
        meta = build_metadata(project)
        File.write(meta_file, JSON.pretty_generate(meta))
      end

      # Invalidate cache for a project
      def invalidate(project)
        cache_key = cache_key_for_project(project)
        cache_file = File.join(@cache_dir, "#{cache_key}.json")
        meta_file = File.join(@cache_dir, "#{cache_key}.meta.json")
        FileUtils.rm_f(cache_file)
        FileUtils.rm_f(meta_file)
      end

      # Clear all cache entries
      def clear!
        FileUtils.rm_rf(@cache_dir)
        FileUtils.mkdir_p(@cache_dir)
      end

      # Get cache statistics
      def stats
        entries = Dir.glob(File.join(@cache_dir, "*.json")).size / 2
        total_size = Dir.glob(File.join(@cache_dir, "*.json")).sum { |f| File.size(f) }
        {entries: entries, size_bytes: total_size}
      end

      private

      def cache_key_for_project(project)
        Digest::SHA256.hexdigest(project.root)[0..15]
      end

      def cache_valid?(project, meta)
        meta["files"].each do |file_info|
          path = file_info["path"]
          next unless File.exist?(path)
          return false if File.mtime(path).to_i != file_info["mtime"]
          return false if File.size(path) != file_info["size"]
        end
        true
      end

      def build_metadata(project)
        files = project.valid_source_files.map do |sf|
          {
            path: sf.path,
            mtime: File.mtime(sf.path).to_i,
            size: File.size(sf.path)
          }
        end
        {
          project_root: project.root,
          generated_at: Time.now.iso8601,
          files: files
        }
      end

      def serialize_analysis_result(result)
        {
          symbol_table: serialize_symbol_table(result.symbol_table),
          type_table: serialize_type_table(result.type_table)
        }
      end

      def serialize_symbol_table(table)
        classes = {}
        methods = {}
        constants = {}

        table.each_symbol do |sym|
          case sym.kind
          when :method
            if sym.namespace
              classes[sym.namespace] ||= {file: sym.file_path, line: sym.line}
            end
            methods[build_method_key(sym.name, sym.namespace, true)] = {file: sym.file_path, line: sym.line}
          when :constant
            constants[sym.name.to_s] = {file: sym.file_path, line: sym.line}
          end
        end

        {
          classes: classes,
          methods: methods,
          constants: constants
        }
      end

      def build_method_key(name, namespace, instance_method)
        ns = namespace || "Object"
        separator = instance_method ? "#" : "."
        "#{ns}#{separator}#{name}"
      end

      def serialize_type_table(table)
        {
          classes: table.all_classes.transform_values { |t| serialize_type(t) },
          methods: table.all_methods,
          constants: table.all_constants,
          stats: table.stats
        }
      end

      def serialize_type(type)
        case type
        when Reweave::Semantic::PrimitiveType
          {type: "PrimitiveType", name: type.name}
        when Reweave::Semantic::ClassType
          {
            type: "ClassType",
            name: type.name,
            namespace: type.namespace,
            superclass: type.superclass&.name,
            methods: type.defined_methods.transform_values { |m| {return_type: serialize_type(m[:return_type]), param_types: m[:param_types].map { |pt| serialize_type(pt) }} }
          }
        when Reweave::Semantic::UnionType
          {type: "UnionType", types: type.types.map { |t| serialize_type(t) }}
        when Reweave::Semantic::UnknownType
          {type: "UnknownType"}
        else
          {type: "UnknownType"}
        end
      end

      def reconstruct_analysis_result(data)
        symbol_table = reconstruct_symbol_table(data["symbol_table"])
        type_table = reconstruct_type_table(data["type_table"])
        AnalysisResult.new(symbol_table, type_table)
      end

      def reconstruct_symbol_table(data)
        table = SymbolTable.new
        data["classes"].each do |name, info|
          table.add_class(name.to_sym, info["file"], info["line"])
        end
        data["methods"].each do |name, info|
          table.add_method(name.to_sym, info["file"], info["line"])
        end
        data["constants"].each do |name, info|
          table.add_constant(name.to_sym, info["file"], info["line"])
        end
        table
      end

      def reconstruct_type_table(data)
        table = TypeTable.new
        data["classes"].each do |name, type_data|
          table.add_class(name.to_sym, reconstruct_type(type_data))
        end
        table
      end

      def reconstruct_type(data)
        case data["type"]
        when "PrimitiveType"
          TypeFactory.primitive(data["name"])
        when "ClassType"
          superclass = data["superclass"] ? TypeFactory.class_type(data["superclass"].to_sym) : nil
          ct = TypeFactory.class_type(data["name"].to_sym, namespace: data["namespace"]&.to_sym, superclass: superclass)
          data["methods"].each do |name, m|
            ct.add_method(name.to_sym, reconstruct_type(m["return_type"]), m["param_types"].map { |pt| reconstruct_type(pt) })
          end
          ct
        when "UnionType"
          TypeFactory.union(*data["types"].map { |t| reconstruct_type(t) })
        when "UnknownType"
          TypeFactory.unknown
        else
          TypeFactory.unknown
        end
      end
    end
  end
end
