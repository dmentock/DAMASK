#ifndef CLI_H
#define CLI_H

#ifdef BOOST

#include <string>
#include <iostream>
#include <iterator>
#include <filesystem>
#include <chrono>
#include <iomanip>
#include <boost/program_options.hpp>
#include <fstream>
#include <vector>
#include <memory>
#include <sstream>

namespace po = boost::program_options;
namespace fs = std::filesystem;
using namespace std;

class MultiStream : public std::ostream {
  class MultiBuffer : public std::streambuf {
    std::vector<std::streambuf*> buffers;
  protected:
    virtual int overflow(int c) override {
      if (c == EOF) return !EOF;
      for (auto buf : buffers) {
        buf->sputc(c);
      }
      return c;
    }

    virtual int sync() override {
      int result = 0;
      for (auto buf : buffers) {
        if (buf->pubsync() != 0) result = -1;
      }
      return result;
    }

  public:
    void add_buffer(std::streambuf* buf) {
      buffers.push_back(buf);
    }
  };

  MultiBuffer buffer;

public:
  MultiStream() : std::ostream(&buffer) {}

  void add_stream(std::ostream& stream) {
    buffer.add_buffer(stream.rdbuf());
  }
};

class CLI {
public:
  int restart_inc = 0;
  fs::path geom_path,
           loadfile_path,
           material_path,
           numerics_path,
           work_dir;
  std::string jobname, uuid;

  MultiStream cout;
  std::ofstream logfile;

  CLI(int* argc, char* argv[], int* worldrank);
  void init_print();
  void help_print(const po::options_description& flags, bool include_restart);

private:
  static std::string generate_uuid();
  static std::string stem(const std::string& fullname);
  static std::string get_hostname();
  static std::string get_username();
  static std::string clean_path(const std::string& path);
  void change_dir(const std::string& path);
};

#endif
#endif // CLI_H
