require_relative "cli_test_case"

class CliProxyTest < CliTestCase
  test "boot" do
    run_command("boot").tap do |output|
      assert_match "docker login", output
      assert_match "docker run --name kamal-proxy --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume kamal-proxy:/root/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE}", output
    end
  end

  test "reboot" do
    Kamal::Commands::Registry.any_instance.expects(:login).twice

    run_command("reboot", "-y").tap do |output|
      assert_match "docker container stop kamal-proxy", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "docker run --name kamal-proxy --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume kamal-proxy:/root/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE}", output
    end
  end

  test "reboot --rolling" do
    run_command("reboot", "--rolling", "-y").tap do |output|
      assert_match "Running docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.1", output
    end
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match "docker container start kamal-proxy", output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match "docker container stop kamal-proxy", output
    end
  end

  test "restart" do
    Kamal::Cli::Proxy.any_instance.expects(:stop)
    Kamal::Cli::Proxy.any_instance.expects(:start)

    run_command("restart")
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter name=^kamal-proxy$", output
    end
  end

  test "logs" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "kamal-proxy", " --tail 100", "--timestamps", "2>&1")
      .returns("Log entry")

    run_command("logs").tap do |output|
      assert_match "Proxy Host: 1.1.1.1", output
      assert_match "Log entry", output
    end
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker logs kamal-proxy --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker logs kamal-proxy --timestamps --tail 10 --follow", run_command("logs", "--follow")
  end

  test "remove" do
    Kamal::Cli::Proxy.any_instance.expects(:stop)
    Kamal::Cli::Proxy.any_instance.expects(:remove_container)
    Kamal::Cli::Proxy.any_instance.expects(:remove_image)

    run_command("remove")
  end

  test "remove_container" do
    run_command("remove_container").tap do |output|
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
    end
  end

  test "remove_image" do
    run_command("remove_image").tap do |output|
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Proxy.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
