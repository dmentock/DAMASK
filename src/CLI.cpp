#ifdef BOOST
#include <ISO_Fortran_binding.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <limits.h>
#include <iostream>
#include <mpi.h>
#include <cstring>
#include <string>
#include <petsc.h>
#include <format>

#include <iomanip>

#include <boost/uuid/uuid.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <boost/uuid/uuid_generators.hpp>
#include <boost/lexical_cast.hpp>

#include "CLI.h"

CLI::CLI(int* argc, char* argv[], int* worldrank) {
  fs::path arg_geom, arg_load, arg_material, arg_numerics, arg_wd;
  std::string arg_jobname;
  int arg_rs = -1;

  cout.add_stream(std::cout);
#ifdef LOGFILE
  std::ostringstream filename;
  filename << "out." << std::setfill('0') << std::setw(4) << *worldrank;
  logfile = std::ofstream(filename.str());
  cout.add_stream(logfile);
#endif

  po::options_description flags("Flags");
  flags.add_options()
    ("help,h", "show help")
    ("geom,g", po::value<fs::path>(&arg_geom)->value_name("geom"), "geometry file")
    ("geometry", po::value<fs::path>(&arg_geom)->value_name("geom"), "alias")
    ("load,l", po::value<fs::path>(&arg_load)->value_name("load"), "load case")
    ("loadcase", po::value<fs::path>(&arg_load)->value_name("load"), "alias")
    ("material,m", po::value<fs::path>(&arg_material)->value_name("material"), "material config")
    ("materialconfig", po::value<fs::path>(&arg_material)->value_name("material"), "alias")
    ("numerics,n", po::value<fs::path>(&arg_numerics)->value_name("numerics"), "numerics config")
    ("numericsconfig", po::value<fs::path>(&arg_numerics)->value_name("numerics"), "alias")
    ("job,j", po::value<std::string>(&arg_jobname)->value_name("job"), "job name")
    ("jobname", po::value<std::string>(&arg_jobname)->value_name("job"), "alias")
    ("workingdir,w", po::value<fs::path>(&arg_wd)->value_name("wd"), "working dir")
    ("workingdirectory,wd", po::value<fs::path>(&arg_wd)->value_name("wd"), "alias")
    ("restart,r", po::value<int>(&arg_rs)->value_name("rs"), "restart increment")
    ("rs", po::value<int>(&arg_rs)->value_name("rs"), "alias");

  po::variables_map vm;

  try {
    po::store(po::parse_command_line(*argc, argv, flags), vm);
    po::notify(vm);
  } catch (const po::error& e) {
    std::cerr << "CLI error: " << e.what() << "\n\n" << flags << "\n";
    std::exit(EXIT_FAILURE);
  }

  if (vm.count("help") || *argc == 1) {
#ifdef GRID
    CLI::help_print(flags, true);
#else
    CLI::help_print(flags, false);
#endif
    std::exit(0);
  }

  geom_path = clean_path(arg_geom.string());
  loadfile_path = clean_path(arg_load.string());
  material_path = clean_path(arg_material.string());

  if (!arg_numerics.empty())
    numerics_path = clean_path(arg_numerics.string());

  if (!arg_jobname.empty())
    jobname = arg_jobname;
  else {
    jobname  = stem(geom_path) + "_" + stem(loadfile_path) + "_" + stem(material_path);
    if (!arg_numerics.empty())
      jobname += "_" + stem(numerics_path);
  }

  if (!arg_wd.empty()) {
    change_dir(clean_path(arg_wd.string()));
  }

  if (arg_rs != -1)
      restart_inc = arg_rs;

  if (*worldrank==0){
    uuid = generate_uuid();
  }

  init_print();
  cout << "Host name: " << get_hostname() << std::endl;
  cout << "User name: " << get_username() << std::endl;
  cout << "\nCommand line call: ";
  for (int i = 0; i < *argc; ++i) {
    cout << argv[i] << " ";
  }
  cout << std::endl;
  cout << "Working directory: " << fs::current_path().string() << std::endl;
  cout << "Geometry: " << geom_path << std::endl;
  cout << "Load case: " << loadfile_path << std::endl;
  cout << "Material config: " << material_path << std::endl;
  if (vm.count("numerics")) {
    cout << "Numerics config: " << numerics_path << std::endl;
  }
  cout << "Job name: " << jobname << std::endl;
  cout << "Job ID: " << uuid << std::endl;
  cout << "Restart from increment: " << restart_inc << std::endl;
}

std::string IO_color(const std::initializer_list<int>& rgb = {}) {
  if (rgb.size() == 3) {
    return "\033[38;2;" + std::to_string(*(rgb.begin())) + ";" +
            std::to_string(*(rgb.begin() + 1)) + ";" +
            std::to_string(*(rgb.begin() + 2)) + "m";
  }
  return "\033[0m";}


void CLI::init_print() {
  std::stringstream output;

#ifdef DEBUG
  output << IO_color({255,0,0});
  output << "debug version - debug version - debug version - debug version - debug version\n";
#else
  output << IO_color({67,128,208});
#endif
  output << R"(
    _/_/_/      _/_/    _/      _/    _/_/      _/_/_/  _/    _/    _/_/_/
   _/    _/  _/    _/  _/_/  _/_/  _/    _/  _/        _/  _/            _/
  _/    _/  _/_/_/_/  _/  _/  _/  _/_/_/_/    _/_/    _/_/          _/_/
 _/    _/  _/    _/  _/      _/  _/    _/        _/  _/  _/            _/
_/_/_/    _/    _/  _/      _/  _/    _/  _/_/_/    _/    _/    _/_/_/

)";

#if defined(GRID)
  output << IO_color({123,207,68});
  output << "Grid solver\n\n";
#elif defined(MESH)
  output << IO_color({230,150,68});
  output << "Mesh solver\n\n";
#endif

#ifdef DEBUG
  output << IO_color({255,0,0});
  output << "debug version - debug version - debug version - debug version - debug version\n\n";
#endif

  output << IO_color();
  output << "F. Roters et al., Computational Materials Science 158:420–478, 2019\n"
          << "https://doi.org/10.1016/j.commatsci.2018.04.030\n\n";

#if PETSC_VERSION_MAJOR==3 && PETSC_VERSION_MINOR>=18
  output << "S. Balay et al., PETSc/TAO User Manual Revision " << PETSC_VERSION_MAJOR << "." << PETSC_VERSION_MINOR << "\n";

#ifdef PETSC_DOI
  output << "https://doi.org/" << PETSC_DOI << endl;
#endif
  output << endl;

#endif
  output << "Version: " << DAMASK_VERSION << "\n\n";
  output << "Compiled with: ";
#if defined(__clang__)
  output << "Clang Version: "
          << __clang_major__ << "."
          << __clang_minor__ << "."
          << __clang_patchlevel__ << std::endl;
#elif defined(__GNUC__)
  output << "GCC Version: "
          << __GNUC__ << "."
          << __GNUC_MINOR__ << "."
          << __GNUC_PATCHLEVEL__ << std::endl;
#elif defined(__INTEL_COMPILER)
  output << "Intel Compiler Version: "
          << __INTEL_COMPILER << "."
          << __INTEL_COMPILER_UPDATE << std::endl;
#else
  throw std::runtime_error("Unknown Compiler");
#endif
  // output << "Compiler options: "; TODO
  output << "Compiled on: " << __DATE__ << " at " << __TIME__ << "\n";
  output << "PETSc version: " << PETSC_VERSION_MAJOR << "." << PETSC_VERSION_MINOR << ".x\n";
  auto now = std::chrono::system_clock::now();
  auto in_time_t = std::chrono::system_clock::to_time_t(now);
  output << "Date: " << std::put_time(std::localtime(&in_time_t), "%d.%m.%Y") << std::endl;
  output << "Time: " << std::put_time(std::localtime(&in_time_t), "%X") << std::endl;
  cout << output.str() << std::endl;
}

void CLI::help_print(const po::options_description& flags, bool include_restart) {
  static constexpr const char* HEAD = R"(
#######################################################################
DAMASK Command Line Interface:
Düsseldorf Advanced Material Simulation Kit with PETSc-based solvers
#######################################################################

Valid command line flags:
)";

  static constexpr const char* FLAGS_DESCRIPTION = R"(
-----------------------------------------------------------------------
Mandatory flags:

--geom GEOMFILE
      Relative or absolute path to a VTK image data file (*.vti)
      with mandatory "material" field variable.

--load LOADFILE
      Relative or absolute path to a load case definition
      in YAML format.

--material MATERIALFILE
      Relative or absolute path to a material configuration
      in YAML format.

-----------------------------------------------------------------------
Optional flags:

--numerics NUMERICSFILE
      Relative or absolute path to a numerics configuration
      in YAML format.

--jobname JOBNAME
      Job name, defaults to GEOM_LOAD_MATERIAL[_NUMERICS].

--workingdir WORKINGDIRECTORY
      Working directory, defaults to current directory and
      serves as base directory of relative paths.
)";

  static constexpr const char* RESTART = R"(
--restart N
      Restart simulation from given increment.
      Read in increment N and, based on this, continue with
      calculating increments N+1, N+2, ...
      Requires restart information for increment N to be present in
      JOBNAME_restart.hdf5 and will append subsequent results to
      existing file JOBNAME.hdf5.
)";

  static constexpr const char* TAIL = R"(
-----------------------------------------------------------------------
Help:

--help
      Display help and exit.

#######################################################################
)";
  cout << HEAD
            << flags
            << FLAGS_DESCRIPTION;

  if (include_restart)
      cout << RESTART;
  cout << TAIL << std::endl;
}

// Cleaning method necessary because backward compatibility requires support of arguments with "=" after flag
std::string CLI::clean_path(const std::string& path) {
  if (!path.empty() && path[0] == '=') {
    return path.substr(1);
  }
  return path;
}

std::string CLI::stem(const std::string& fullname) {
  fs::path p(fullname);
  return p.stem().string();
}

std::string CLI::get_hostname() {
  char hostname[256];
  if (gethostname(hostname, sizeof(hostname)) == 0) {
    return std::string(hostname);
  } else {
    return "n/a (Error getting hostname)";
  }
}

std::string CLI::get_username() {
  struct passwd *pw = getpwuid(getuid());
  if (pw != nullptr) {
    return std::string(pw->pw_name);
  } else {
    return "n/a (Error getting username)";
  }
}

void CLI::change_dir(const std::string& path) {
  if (chdir(path.c_str()) != 0) {
    std::string errorStr = strerror(errno);
    throw std::runtime_error("Failed to change directory to \"" + path + "\": " + errorStr);
  }
}

std::string CLI::generate_uuid() {
  return boost::lexical_cast<std::string>(
          boost::uuids::random_generator()());
}

extern "C" {
  CLI* CLI__new(int* argc, char* argv[], int* worldrank) {
      return new CLI(argc, argv, worldrank);
  }

  void C_CLI_get_parsed_args (CLI *cli,
                              CFI_cdesc_t *geom,
                              CFI_cdesc_t *load,
                              CFI_cdesc_t *material,
                              CFI_cdesc_t *numerics,
                              CFI_cdesc_t *uuid,
                              CFI_cdesc_t *jobname,
                              int* restart,
                              int* stat) {
    auto put_string = [](const std::string &src, CFI_cdesc_t *dest) -> int {
      const char *src_c = src.c_str();
      int len = std::strlen(src_c);
      if (len!=0) {
        if (CFI_allocate(dest, (CFI_index_t *)0, (CFI_index_t *)0, len) == 0)
          std::memcpy(dest->base_addr, src_c, len);
          return 0;
      }
      return 1;
    };

    const std::pair<std::string, CFI_cdesc_t*> cli_args[] = {
      {cli->geom_path.string(),   geom},
      {cli->loadfile_path.string(),   load},
      {cli->material_path.string(), material},
      {cli->numerics_path.string(), numerics},
      {cli->jobname, jobname},
      {cli->uuid, uuid}
    };

    for (const auto &arg : cli_args) {
      if (arg.first.empty())
        continue;
      if (put_string(arg.first, arg.second) != 0) {
        *stat = 1;
        return;
      }
    }
    *restart = cli->restart_inc;

    *stat = 0;
  }
}

#endif
