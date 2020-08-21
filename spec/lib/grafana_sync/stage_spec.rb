require 'grafana_sync'

# Crude tests to fixate behaviour.
RSpec.describe GrafanaSync::Stage do

  subject(:stage) do
    described_class.new(stage: :test,
                        make_folders: make_folders,
                        debug: false)
  end

  TMP_DIR = 'tmp'

  let(:make_folders) { false }

  before {
    allow(GrafanaSync).to receive(:load_config)
    allow_any_instance_of(GrafanaSync::Stage)
      .to receive(:credentials).and_return({login: 'login', password: 'password'})
    GrafanaSync::Stage::DASHBOARDS_ROOT = 'spec/fixtures/output_samples/'

    [
      ['/api/search', '/api.search.json'],
      ['/api/dashboards/uid/r6k10qgGz', '/get_The Dashboard.json'],
      ['/api/dashboards/uid/dpZCAqRMz', '/get_Dashboard Dummy 1.json'],
      ['/api/dashboards/uid/cM9Q03gGk', '/get_Dashboard Dummy 2.json']
    ].each do |api_path, body_path|
      stub_request(:get, "http://test.url" + api_path).
        with(
          headers: {
            'Authorization'=>'Basic bG9naW46cGFzc3dvcmQ=',
            'Connection'=>'close',
            'Host'=>'test.url'
          }).
        to_return(status: 200, body: IO.read('spec/fixtures/mocks' + body_path),
                  headers: {'Content-Type' => 'application/json'})
    end
  }

  it 'sample config is correct' do
    load('sample_repo/config.rb')
  end

  it 'pulls' do
    GrafanaSync.merge_config({
                               test: {
                                 url: "http://test.url",
                                 folder: "Test",
                               }
                             })
    GrafanaSync::Stage::DASHBOARDS_ROOT = TMP_DIR
    FileUtils.rm_rf(Dir.glob(TMP_DIR + '/*'))
    stage.pull

    result_files = Dir.glob(TMP_DIR + '/*.json').map! {|path| File.basename(path)}
    expected_files = Dir.glob('spec/fixtures/output_samples/*.json').map! {|path| File.basename(path)}
    expect(result_files).to eq(expected_files)

    expected_files.each do |filename|
      expect(JSON.parse(IO.read(File.join(TMP_DIR, filename))))
        .to eq(JSON.parse(IO.read("spec/fixtures/output_samples/#{filename}")))
    end
  end

  it 'pushes into existing folder' do
    GrafanaSync.merge_config({
                               test: {
                                 url: "http://test.url",
                                 folder: "Test2",
                               }
                             })

    delete = stub_request(:delete, "http://test.url/api/dashboards/uid/cM9Q03gGk").
      with(
        body: "{}",
        headers: {
          'Authorization'=>'Basic bG9naW46cGFzc3dvcmQ=',
          'Connection'=>'close',
          'Content-Type'=>'application/json; charset=UTF-8',
          'Host'=>'test.url',
        }).
      to_return(status: 200,
                body: '{"message":"Dashboard Dashboard Dummy 2 deleted","title":"Dashboard Dummy 2"}',
                headers: {})

    post_1 = stub_request(:post, "http://test.url/api/dashboards/db").
      with(
        body: "{\"dashboard\":{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":\"-- Grafana --\",\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations \\u0026 Alerts\",\"type\":\"dashboard\"}]},\"editable\":true,\"gnetId\":null,\"graphTooltip\":0,\"links\":[],\"panels\":[{\"aliasColors\":{},\"bars\":false,\"cacheTimeout\":null,\"dashLength\":10,\"dashes\":false,\"datasource\":null,\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":9,\"w\":12,\"x\":0,\"y\":0},\"hiddenSeries\":false,\"id\":2,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"dataLinks\":[]},\"percentage\":false,\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"refId\":\"A\",\"scenarioId\":\"random_walk\"}],\"thresholds\":[],\"timeFrom\":null,\"timeRegions\":[],\"timeShift\":null,\"title\":\"Panel Title\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"buckets\":null,\"mode\":\"time\",\"name\":null,\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"label\":null,\"logBase\":1,\"max\":null,\"min\":null,\"show\":true},{\"format\":\"short\",\"label\":null,\"logBase\":1,\"max\":null,\"min\":null,\"show\":true}],\"yaxis\":{\"align\":false,\"alignLevel\":null}}],\"schemaVersion\":21,\"style\":\"dark\",\"tags\":[],\"templating\":{\"list\":[]},\"time\":{\"from\":\"now-6h\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"]},\"timezone\":\"\",\"title\":\"Dashboard Dummy 1\"},\"folderId\":256,\"overwrite\":true}",
        headers: {
          'Authorization'=>'Basic bG9naW46cGFzc3dvcmQ=',
          'Connection'=>'close',
          'Content-Type'=>'application/json; charset=UTF-8',
          'Host'=>'test.url',
        }).
      to_return(status: 200, body:
        '{"id":259,"slug":"dashboard-dummy-1","status":"success","uid":"zgj_fgkGz","url":"/d/zgj_fgkGz/dashboard-dummy-1","version":1}',
                headers: {})

    post_2 = stub_request(:post, "http://test.url/api/dashboards/db").
      with(
        body: "{\"dashboard\":{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":\"-- Grafana --\",\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations \\u0026 Alerts\",\"type\":\"dashboard\"}]},\"editable\":true,\"gnetId\":null,\"graphTooltip\":0,\"links\":[],\"panels\":[{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":\"TestData DB\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":9,\"w\":12,\"x\":0,\"y\":0},\"hiddenSeries\":false,\"id\":2,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"nullPointMode\":\"null\",\"options\":{\"dataLinks\":[]},\"percentage\":false,\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"refId\":\"A\",\"scenarioId\":\"random_walk_table\",\"stringInput\":\"\"},{\"csvWave\":{\"timeStep\":60,\"valuesCSV\":\"0,0,2,2,1,1\"},\"refId\":\"B\",\"scenarioId\":\"predictable_csv_wave\",\"stringInput\":\"\"}],\"thresholds\":[],\"timeFrom\":null,\"timeRegions\":[],\"timeShift\":null,\"title\":\"Panel 1\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"buckets\":null,\"mode\":\"time\",\"name\":null,\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"label\":null,\"logBase\":1,\"max\":null,\"min\":null,\"show\":true},{\"format\":\"short\",\"label\":null,\"logBase\":1,\"max\":null,\"min\":null,\"show\":true}],\"yaxis\":{\"align\":false,\"alignLevel\":null}},{\"columns\":[],\"datasource\":null,\"fontSize\":\"100%\",\"gridPos\":{\"h\":9,\"w\":12,\"x\":12,\"y\":0},\"id\":4,\"options\":{},\"pageSize\":null,\"pluginVersion\":\"6.5.2\",\"showHeader\":true,\"sort\":{\"col\":0,\"desc\":true},\"styles\":[{\"alias\":\"Time\",\"dateFormat\":\"YYYY-MM-DD HH:mm:ss\",\"pattern\":\"Time\",\"type\":\"date\"},{\"alias\":\"\",\"colorMode\":null,\"colors\":[\"rgba(245, 54, 54, 0.9)\",\"rgba(237, 129, 40, 0.89)\",\"rgba(50, 172, 45, 0.97)\"],\"decimals\":2,\"pattern\":\"/.*/\",\"thresholds\":[],\"type\":\"number\",\"unit\":\"short\"}],\"targets\":[{\"refId\":\"A\",\"scenarioId\":\"logs\",\"stringInput\":\"\"},{\"pulseWave\":{\"offCount\":3,\"offValue\":1,\"onCount\":3,\"onValue\":2,\"timeStep\":60},\"refId\":\"B\",\"scenarioId\":\"predictable_pulse\",\"stringInput\":\"\"}],\"timeFrom\":null,\"timeShift\":null,\"title\":\"Panel 2\",\"transform\":\"table\",\"type\":\"table\"}],\"schemaVersion\":21,\"style\":\"dark\",\"tags\":[],\"templating\":{\"list\":[]},\"time\":{\"from\":\"now-6h\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"]},\"timezone\":\"\",\"title\":\"The Dashboard\"},\"folderId\":256,\"overwrite\":true}",
        headers: {
          'Authorization'=>'Basic bG9naW46cGFzc3dvcmQ=',
          'Connection'=>'close',
          'Content-Type'=>'application/json; charset=UTF-8',
          'Host'=>'test.url',
        }).
      to_return(status: 200, body:
        '{"id":260,"slug":"the-dashboard","status":"success","uid":"-MjlBgkMz","url":"/d/-MjlBgkMz/the-dashboard","version":1}',
                headers: {})

    stage.push

    expect(delete).to have_been_requested
    expect(post_1).to have_been_requested
    expect(post_2).to have_been_requested
  end

  it "with make_folder disabled and folder is missing doesn't push and exit" do
    GrafanaSync.merge_config({
                               test: {
                                 url: "http://test.url",
                                 folder: "non_existant",
                               }
                             })

    expect { stage.push }.to raise_error(SystemExit)
  end

  context 'with make_folder enabled' do
    let(:make_folders) { true }

    it "creates a folder and pushes" do
      GrafanaSync.merge_config({
                                 test: {
                                   url: "http://test.url",
                                   folder: "non_existant",
                                 }
                               })

      stub_request(:get, 'http://test.url/api/search').
        with(
          headers: {
            'Authorization'=>'Basic bG9naW46cGFzc3dvcmQ=',
            'Connection'=>'close',
            'Host'=>'test.url'
          }).
        to_return({body: IO.read('spec/fixtures/mocks/api.search.json'),
                   headers: {'Content-Type' => 'application/json'}},
                  {body: IO.read('spec/fixtures/mocks/api.search_new-folder.json'),
                   headers: {'Content-Type' => 'application/json'}})

      post = stub_request(:post, "http://test.url/api/folders").
        with(
          body: '{"title":"non_existant"}',
          headers: {
            'Authorization'=>'Basic bG9naW46cGFzc3dvcmQ=',
            'Connection'=>'close',
            'Content-Type'=>'application/json; charset=UTF-8',
            'Host'=>'test.url',
          }).
        to_return(status: 200, body:
          '{"id":264,"uid":"D0LA8gzGz","title":"non_existant","url":"/dashboards/f/D0LA8gzGz/non_existant","hasAcl":false,"canSave":true,"canEdit":true,"canAdmin":true,"createdBy":"n.epifanov","created":"2020-05-22T13:53:27+03:00","updatedBy":"n.epifanov","updated":"2020-05-22T13:53:27+03:00","version":1}',
                  headers: {})

      stub_request(:post, "http://test.url/api/dashboards/db").
        with(
          headers: {
            'Authorization'=>'Basic bG9naW46cGFzc3dvcmQ=',
            'Connection'=>'close',
            'Content-Type'=>'application/json; charset=UTF-8',
            'Host'=>'test.url',
          }).
        to_return(status: 200, body:
          '{"id":260,"slug":"any-dashboard","status":"success","uid":"-MjlBgkMz","url":"/d/-MjlBgkMz/any-dashboard","version":1}',
                  headers: {})

      stage.push
      expect(post).to have_been_requested
    end
  end

  it 'diffs' do
    GrafanaSync.merge_config({
                               test: {
                                 url: "http://test.url",
                                 folder: "Test",
                               }
                             })
    GrafanaSync::Stage::DASHBOARDS_ROOT = 'spec/fixtures/output_samples-changed'
    expect { stage.diff }.to output.to_stdout
  end
end
