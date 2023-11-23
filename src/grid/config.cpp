#include "config.h"

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

std::string Config::read_file(const std::string& file_path) {
    std::ifstream fstream(file_path);
        if (fstream.fail()) {
        throw std::runtime_error("Error: Unable to open file " + file_path);
    }
    std::stringstream buffer;
    buffer << fstream.rdbuf();
    return buffer.str();
};

Config::NumGridParams Config::parse_numerics_yaml(std::string yamlFilePath) {
  NumGridParams numerics;
	std::string yamlContent = read_file(yamlFilePath);

	YAML::Node rootNode = YAML::Load(yamlContent);
	YAML::Node gridNode = rootNode["grid"];

	std::string errors = "";

  for (const auto& key_ : gridNode) {
    std::string key = key_.first.as<std::string>();
		if (key == "N_iter_min") {
				int itmin = key_.second.as<int>();
				if (itmin < 1)  {
					errors += "N_iter_min must be >= 1\n";
				} else {
					numerics.itmin = itmin;
				}
		} else if (key == "N_iter_max") {
				int itmax = key_.second.as<int>();
				if (itmax <= 1)  {
					errors += "N_iter_max must be > 1\n";
				} else {
					numerics.itmax = itmax;
				}
		} else if (key == "memory_efficient") {
				numerics.memory_efficient = key_.second.as<int>();
		} else if (key == "divergence_correction") {
				int divergence_correction = key_.second.as<int>();
				if (divergence_correction < 0 || divergence_correction > 2) 
					errors += "divergence_correction must be => 0 and <= 2\n";
				numerics.divergence_correction = divergence_correction;
		} else if (key == "update_gamma") {
				numerics.update_gamma = key_.second.as<bool>();
		} else if (key == "eps_div_atol") {
				double eps_div_atol = key_.second.as<double>();
				if (eps_div_atol <= 0)  {
					errors += "eps_div_atol must be > 0\n";
				} else {
					numerics.eps_div_atol = eps_div_atol;
				}
		} else if (key == "eps_div_rtol") {
				double eps_div_rtol = key_.second.as<double>();
				if (eps_div_rtol <= 0)  {
					errors += "eps_div_rtol must be >= 0\n";
				} else {
					numerics.eps_div_rtol = eps_div_rtol;
				}
		} else if (key == "eps_stress_atol") {
				double eps_stress_atol = key_.second.as<double>();
				if (eps_stress_atol <= 0)  {
					errors += "eps_stress_atol must be > 0\n";
				} else {
					numerics.eps_stress_atol = eps_stress_atol;
				}
		} else if (key == "eps_stress_rtol") {
				double eps_stress_rtol = key_.second.as<double>();
				if (eps_stress_rtol <= 0)  {
					errors += "eps_stress_rtol must be >= 0\n";
				} else {
					numerics.eps_stress_rtol = eps_stress_rtol;
				}
		} else if (key == "eps_curl_atol") {
				double eps_curl_atol = key_.second.as<double>();
				if (eps_curl_atol <= 0)  {
					errors += "eps_curl_atol must be > 0\n";
				} else {
					numerics.eps_curl_atol = eps_curl_atol;
				}
		} else if (key == "eps_curl_rtol") {
				double eps_curl_rtol = key_.second.as<double>();
				if (eps_curl_rtol <= 0)  {
					errors += "eps_curl_rtol must be >= 0\n";
				} else {
					numerics.eps_curl_rtol = eps_curl_rtol;
				}
		} else if (key == "alpha") {
				double alpha = key_.second.as<double>();
				if (alpha < 0 || alpha > 2)  {
					errors += "alpha must be > 0 and <= 2\n";
				} else {
					numerics.alpha = alpha;
				}
		} else if (key == "beta") {
				double beta = key_.second.as<double>();
				if (beta < 0 || beta > 2)  {
					errors += "beta must be => 0 and <= 2\n";
				} else {
					numerics.beta = beta;
				}
		} else if (key == "eps_thermal_atol") {
				double eps_thermal_atol = key_.second.as<double>();
				if (eps_thermal_atol <= 0)  {
					errors += "eps_thermal_atol must be > 0\n";
				} else {
					numerics.eps_thermal_atol = eps_thermal_atol;
				}
		} else if (key == "eps_thermal_rtol") {
				double eps_thermal_rtol = key_.second.as<double>();
				if (eps_thermal_rtol <= 0)  {
					errors += "eps_thermal_rtol must be > 0\n";
				} else {
					numerics.eps_thermal_rtol = eps_thermal_rtol;
				}
		} else if (key == "eps_damage_atol") {
				double eps_damage_atol = key_.second.as<double>();
				if (eps_damage_atol <= 0)  {
					errors += "eps_damage_atol must be > 0\n";
				} else {
					numerics.eps_damage_atol = eps_damage_atol;
				}
		} else if (key == "eps_damage_rtol") {
				double eps_damage_rtol = key_.second.as<double>();
				if (eps_damage_rtol <= 0)  {
					errors += "eps_damage_rtol must be > 0\n";
				} else {
					numerics.eps_damage_rtol = eps_damage_rtol;
				}
		} else if (key == "phi_min") {
				double phi_min = key_.second.as<double>();
				if (phi_min <= 0)  {
					errors += "phi_min must be => 0\n";
				} else {
					numerics.phi_min = phi_min;
				}
		} else if (key == "petsc_options") {
				numerics.petsc_options = key_.second.as<std::string>();
		} else if (key == "derivative") {
				std::string derivative = key_.second.as<std::string>();
        if (derivative == "continuous") {
            numerics.spectral_derivative_id = DERIVATIVE_CONTINUOUS_ID;
        } else if (derivative == "central_difference") {
            numerics.spectral_derivative_id = DERIVATIVE_CENTRAL_DIFF_ID;
        } else if (derivative == "FWBW_difference") {
            numerics.spectral_derivative_id = DERIVATIVE_FWBW_DIFF_ID;
        } else {
          errors += "derivative must be either 'continuous', 'central_difference' or 'FWBW_difference'\n";
        };
    } else if (key == "fftw_plan_mode") {
      std::string fftw_plan_mode = key_.second.as<std::string>();
      if (fftw_plan_mode == "fftw_estimate") {
        numerics.fftw_planner_flag = FFTW_ESTIMATE;
      } else if (fftw_plan_mode == "fftw_measure") {
        numerics.fftw_planner_flag = FFTW_MEASURE;
      } else if (fftw_plan_mode == "fftw_patient") {
        numerics.fftw_planner_flag = FFTW_PATIENT;
      } else if (fftw_plan_mode == "fftw_exhaustive") {
        numerics.fftw_planner_flag = FFTW_EXHAUSTIVE;
      } else {
        errors += "using default 'FFTW_MEASURE' flag in 'fftw_plan_mode' instead of unknown specified '" + fftw_plan_mode + "'\n";
        numerics.fftw_planner_flag = FFTW_MEASURE;  // Default value
      }
		} else if (key == "fftw_timelimit") {
				double fftw_timelimit = key_.second.as<double>();
				if (fftw_timelimit <= 0)  {
					errors += "fftw_timelimit must be > 0\n";
				} else {
					numerics.fftw_timelimit = fftw_timelimit;
				}
		} else if (key == "maxStaggeredIter") {
				int max_staggered_iter = key_.second.as<int>();
				if (max_staggered_iter < 0) { 
					errors += "maxStaggeredIter must be > 0\n";
				} else {
					numerics.max_staggered_iter = max_staggered_iter;
				};
		} else if (key == "maxCutBack") {
				int max_cut_back = key_.second.as<int>();
				if (max_cut_back < 0) { 
					errors += "maxCutBack must be > 0\n";
				} else {
					numerics.max_cut_back = max_cut_back;
				};
		} else {
				errors+= std::string("Unknown key:") + key;
		}
  }
	if (errors != ""){
		throw std::runtime_error("errors when parsing numerics yaml: \n" + errors);
	}
  return numerics;
}

std::vector<Config::LoadStep> Config::parse_load_yaml(std::string yamlFilePath,
                                  std::map<std::string, std::string>& fields) {
  std::vector<LoadStep> load_steps;
  std::string yamlContent = read_file(yamlFilePath);
  YAML::Node rootNode = YAML::Load(yamlContent);
  YAML::Node gridNode = rootNode["grid"];
  std::string errors = "";

  YAML::Node solverNode = rootNode["solver"];
  fields["mechanical"] = solverNode["mechanical"].as<std::string>();
  if (solverNode["thermal"].IsDefined()) {
    fields["thermal"] = solverNode["thermal"].as<std::string>();
  }
  if (solverNode["damage"].IsDefined()) {
    fields["damage"] = solverNode["damage"].as<std::string>();
  }

  YAML::Node loadstepNodes = rootNode["loadstep"];
  for (int i = 0; i < loadstepNodes.size(); ++i) {
    LoadStep load_step;

    YAML::Node loadstepNode = loadstepNodes[i];
    YAML::Node bcNode = loadstepNode["boundary_conditions"];
    YAML::Node mechanicalNode = bcNode["mechanical"];

    std::vector<std::string> deformation_key_variations = {"dot_F", "L", "F"};
    load_step.deformation = parse_boundary_condition(mechanicalNode, deformation_key_variations);
    if (find(deformation_key_variations.begin(), deformation_key_variations.end(), load_step.deformation.type)
        == deformation_key_variations.end()) {
      throw std::runtime_error(
          "Mandatory key {" +
          std::accumulate(std::next(deformation_key_variations.begin()), deformation_key_variations.end(),
              deformation_key_variations[0],
              [](std::string a, std::string b) {
                  return a + "/" + b;
              }
          )
      + "} missing");
    }

    std::vector<std::string> stress_key_variations = {"dot_P", "P"};
    load_step.stress = parse_boundary_condition(mechanicalNode, stress_key_variations);

    if (mechanicalNode["R"].IsDefined()) {
      YAML::Node rotationNode = mechanicalNode["R"];
      if (rotationNode.size() != 4) {
        throw std::runtime_error("Quaternion in mechanical.R key must have exactly 4 components");
      }
      load_step.rot_bc_q = Eigen::Quaterniond(
        rotationNode[0].as<double>(),
        rotationNode[1].as<double>(),
        rotationNode[2].as<double>(),
        rotationNode[3].as<double>()
      );
    }

    YAML::Node discretizationNode = loadstepNode["discretization"];
    load_step.t = discretizationNode["t"].as<int>();
    load_step.N = discretizationNode["N"].as<int>();
    n_total_load_steps += load_step.N;
    if (discretizationNode["r"].IsDefined()) {
      load_step.r = discretizationNode["r"].as<int>();
    }
    if (loadstepNode["f_out"].IsDefined()) {
      load_step.f_out = loadstepNode["f_out"].as<int>();
    }
    if (loadstepNode["estimate_rate"].IsDefined()) {
      load_step.estimate_rate = (loadstepNode["estimate_rate"].as<bool>() && i>0);
    }
    if (loadstepNode["f_restart"].IsDefined()) {
      load_step.f_restart = loadstepNode["f_restart"].as<int>();
    }
    if (loadstepNode["f_out"].IsDefined()) {
      load_step.f_out = loadstepNode["f_out"].as<int>();
    }
    load_steps.push_back(load_step);
  }
  if (errors != ""){
    throw std::runtime_error("errors when parsing numerics yaml: \n" + errors);
  }
  return load_steps;
}

Config::BoundaryCondition Config::parse_boundary_condition(YAML::Node& mechanicalNode, std::vector<std::string>& key_variations) {
  BoundaryCondition bc;
  bool keyFound = false;
  for (const std::string& key : key_variations) {
    if (mechanicalNode[key].IsDefined()) {
      if (keyFound) {
        // documentation for this constraint missing on website
        throw std::runtime_error(
            "Redundant definition in loadstep boundary condition definition, only one of the following set of keys can be defined: {" +
            std::accumulate(std::next(key_variations.begin()), key_variations.end(),
                key_variations[0],
                [](std::string a, std::string b) {
                    return a + ", " + b;
                }
            )
        + "}");
      }
      keyFound = true;
      bc.type = key;
      YAML::Node matrix_node = mechanicalNode[key];
      for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
          if (matrix_node[i][j].as<std::string>()!="x") {
            bc.mask(i, j) = false;
            bc.values(i, j) = matrix_node[i][j].as<double>();
          }
        }
      }
    }
  }
  return bc;
}
