locals {
  nginx_resource_id = azurerm_nginx_deployment.main.id
  vm1_resource_id   = azurerm_linux_virtual_machine.nginx_vm[0].id
  vm2_resource_id   = azurerm_linux_virtual_machine.nginx_vm[1].id
}

resource "azurerm_portal_dashboard" "nginxaas" {
  name                = "${var.project_prefix}-dashboard"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags = merge(var.tags, {
    "hidden-title" = "NGINXaaS Monitoring Dashboard"
  })

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = {
              x       = 0
              y       = 0
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "Requests / sec"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "plus.worker.http.request.total"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Worker Statistics"
                          aggregationType = 1
                          metricVisualization = {
                            displayName         = "HTTP Requests Total"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        }
                      ]
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = {
                            isVisible = true
                          }
                          y = {
                            isVisible = true
                          }
                        }
                      }
                      timespan = {
                        relative = {
                          duration = 3600000
                        }
                        grain = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }
          "1" = {
            position = {
              x       = 6
              y       = 0
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "Active Connections"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "nginx.conn.active"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Connections Statistics"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "Active Connections"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        }
                      ]
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true }
                          y = { isVisible = true }
                        }
                      }
                      timespan = {
                        relative = { duration = 3600000 }
                        grain    = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }

          "2" = {
            position = {
              x       = 0
              y       = 4
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "HTTP Status Code Distribution"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "plus.http.upstream.peers.status.2xx"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Requests and Response Statistics"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "2xx Responses"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        },
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "plus.http.upstream.peers.status.4xx"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Requests and Response Statistics"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "4xx Responses"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        },
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "plus.http.upstream.peers.status.5xx"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Requests and Response Statistics"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "5xx Responses"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        }
                      ]
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true }
                          y = { isVisible = true }
                        }
                      }
                      timespan = {
                        relative = { duration = 3600000 }
                        grain    = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }

          "3" = {
            position = {
              x       = 6
              y       = 4
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "WAF Blocked Requests (4xx)"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "plus.http.upstream.peers.status.4xx"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Requests and Response Statistics"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "4xx (WAF Blocked)"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        }
                      ]
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true }
                          y = { isVisible = true }
                        }
                      }
                      timespan = {
                        relative = { duration = 3600000 }
                        grain    = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }
          "4" = {
            position = {
              x       = 0
              y       = 8
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "Upstream Response Time"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "plus.http.upstream.peers.response.time"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Upstream Statistics"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "Response Time (ms)"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        }
                      ]
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true }
                          y = { isVisible = true }
                        }
                      }
                      timespan = {
                        relative = { duration = 3600000 }
                        grain    = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }

          "5" = {
            position = {
              x       = 6
              y       = 8
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "Upstream Server State (1=Up, 0=Down)"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.nginx_resource_id
                          }
                          name            = "plus.http.upstream.peers.state"
                          namespace       = "NGINX.NGINXPLUS/nginxDeployments"
                          customNamespace = "NGINX Upstream Statistics"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "Upstream Peer State"
                            resourceDisplayName = "${var.project_prefix}-nginxaas"
                          }
                        }
                      ]
                      grouping = {
                        dimension = "upstream"
                        sort      = 2
                        top       = 10
                      }
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true }
                          y = {
                            isVisible = true
                            axisType  = 1
                          }
                        }
                      }
                      timespan = {
                        relative = { duration = 3600000 }
                        grain    = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }

          "6" = {
            position = {
              x       = 0
              y       = 12
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "VM1 CPU Utilization (%)"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.vm1_resource_id
                          }
                          name            = "Percentage CPU"
                          namespace       = "Microsoft.Compute/virtualMachines"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "CPU %"
                            resourceDisplayName = "${var.project_prefix}-vm1"
                          }
                        }
                      ]
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true }
                          y = { isVisible = true }
                        }
                      }
                      timespan = {
                        relative = { duration = 3600000 }
                        grain    = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }

          "7" = {
            position = {
              x       = 6
              y       = 12
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name = "options"
                  value = {
                    chart = {
                      title = "VM2 CPU Utilization (%)"
                      metrics = [
                        {
                          resourceMetadata = {
                            id = local.vm2_resource_id
                          }
                          name            = "Percentage CPU"
                          namespace       = "Microsoft.Compute/virtualMachines"
                          aggregationType = 4
                          metricVisualization = {
                            displayName         = "CPU %"
                            resourceDisplayName = "${var.project_prefix}-vm2"
                          }
                        }
                      ]
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true }
                          y = { isVisible = true }
                        }
                      }
                      timespan = {
                        relative = { duration = 3600000 }
                        grain    = 1
                      }
                    }
                  }
                  isOptional = true
                },
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                }
              ]
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })

  depends_on = [
    azurerm_nginx_deployment.main,
    azurerm_linux_virtual_machine.nginx_vm
  ]
}
