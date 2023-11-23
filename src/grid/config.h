#ifndef YAML_READER_H
#define YAML_READER_H

#include <yaml-cpp/yaml.h>

#include <unsupported/Eigen/CXX11/Tensor>
#include <Eigen/Geometry> 
#include <Eigen/Dense>
#include <fftw3.h>

#include <unordered_map>
#include <string>
#include <map> 

using namespace std;
using namespace Eigen;

class Config {
public:

  enum derivative_ids { 
    DERIVATIVE_CONTINUOUS_ID,
    DERIVATIVE_CENTRAL_DIFF_ID,
    DERIVATIVE_FWBW_DIFF_ID
  };

  struct NumGridParams {
    int max_staggered_iter = 10;
    int max_cut_back = 3;

    int itmin = 1;
    int itmax = 100;
    int memory_efficient = 1;
    int divergence_correction = 2;
    bool update_gamma = false;

    double eps_div_atol = 1e-4;
    double eps_div_rtol = 5e-4;
    double eps_stress_atol = 1e+3;
    double eps_stress_rtol = 1e-3;
    double eps_curl_atol = 1e-10;
    double eps_curl_rtol = 5e-4;

    double alpha = 1;
    double beta = 1;
    
    double eps_thermal_atol = 1e-2;
    double eps_thermal_rtol = 1e-6;

    double eps_damage_atol = 1e-2;
    double eps_damage_rtol = 1e-6;
    double phi_min = 1e-6;

    std::string petsc_options = "";
    int fftw_planner_flag = FFTW_MEASURE;
    double fftw_timelimit = 300;

    int spectral_derivative_id = 0; // TODO: discuss if altering the structure of the original yaml here makes sense
  };

  struct BoundaryCondition {
    Matrix<double, 3, 3> values = Eigen::Matrix<double, 3, 3>::Zero();;
    Matrix<bool, 3, 3> mask = Eigen::Matrix<bool, 3, 3>::Constant(true);;
    std::string type;
  };

  struct LoadStep {
    BoundaryCondition stress;
    BoundaryCondition deformation;
    Quaterniond rot_bc_q = Quaterniond(1, 0, 0, 0);
    int t;
    double N;
    int r = 1;
    bool estimate_rate = true;
    int f_out = 1;
    int f_restart = 0;
  };

  struct SolutionState {
    int required_iterations = 0;
    bool converged = true;
    bool stag_converged = true;
    bool terminally_ill = false;
  };

  struct SolutionParams {
    Eigen::Matrix<double, 3, 3> stress_bc;
    Eigen::Matrix<bool, 3, 3> stress_mask;
    Eigen::Quaterniond rot_bc_q;
    double delta_t;
  };

  std::map<std::string, std::string> fields;
  NumGridParams numerics;
  std::vector<LoadStep> load_steps;
  std::string vti_file_content;

  int n_total_load_steps = 0;

  static NumGridParams parse_numerics_yaml(std::string yamlFilePath);
  std::vector<LoadStep> parse_load_yaml(std::string yamlFilePath,
                              std::map<std::string, std::string>& fields);
  static BoundaryCondition parse_boundary_condition(YAML::Node& mechanicalNode, std::vector<std::string>& key_variations);
  static std::string read_file(const std::string& file_path);
};

#endif // YAML_READER_H
