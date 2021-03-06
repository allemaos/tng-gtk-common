## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# frozen_string_literal: true
# encoding: utf-8
require_relative '../spec_helper'

RSpec.describe FetchPackagesService do
  let(:catalogue_url)  {FetchPackagesService::CATALOGUE_URL}
  
  it 'breaks unless CATALOGUE_URL ENV message is defined' do
    expect(described_class.const_defined?(:CATALOGUE_URL)).to be_truthy   
  end
  
  describe 'Accepts status queries' do
    let(:unpackager_url)  {FetchPackagesService::UNPACKAGER_URL}
    let(:possible_status) { ["waiting", "running", "failed", "success"]}
    let(:valid_processing_uuid) {SecureRandom.uuid}
    let(:status_message) { {package_process_uuid: valid_processing_uuid, status: "running", error_msg: ""}}
    it 'breaks unless UNPACKAGER_URL ENV message is defined' do
      expect(described_class.const_defined?(:UNPACKAGER_URL)).to be_truthy   
    end
    it "returning nil when it doesn't find the package" do
      stub_request(:get, unpackager_url+'/status/'+valid_processing_uuid).
        to_return(status: 404, body: '', headers: {'content-type' => 'application/json'})
      expect(described_class.status(valid_processing_uuid)).to be_nil
    end
    it "returning valid data" do
      stub_request(:get, unpackager_url+'/status/'+valid_processing_uuid).
        to_return(status: 200, body: status_message.to_json, headers: {'content-type' => 'application/json'})
      expect(described_class.status(valid_processing_uuid)).to eq(status_message)
    end
  end
  
  describe '.metadata' do    
    let(:uuid_1) {SecureRandom.uuid}
    let(:uuid_2) {SecureRandom.uuid}
    let(:package_1_metadata) {{package_uuid: uuid_1, pd: {vendor: '5gtango', name: 'whatever', version: '0.0.1'}}}
    let(:package_2_metadata) {{package_uuid: uuid_2, pd: {vendor: '5gtango', name: 'whatever', version: '0.0.2'}}}
    let(:packages_metadata) {[package_1_metadata,package_2_metadata]}
    let(:default_page_size) {ENV.fetch('DEFAULT_PAGE_SIZE', '100')}
    let(:default_page_number) {ENV.fetch('DEFAULT_PAGE_NUMBER', '0')}
    it 'calls the Catalogue with default params' do      
      stub_request(:get, catalogue_url+'/packages?page_number='+default_page_number+'&page_size='+default_page_size).to_return(status: 200, body: packages_metadata.to_json, headers: {'content-type' => 'application/json'})
      expect(described_class.metadata({})).to eq([package_1_metadata, package_2_metadata])
    end
    it 'calls the Catalogue with default page_size when only page_number is passed' do      
      stub_request(:get, catalogue_url+'/packages?page_number=1&page_size='+default_page_size).to_return(status: 200, body: [].to_json, headers: {'content-type' => 'application/json'})
      expect(described_class.metadata({page_number: 1})).to eq([])
    end
    it 'calls the Catalogue with default page_number when only page_size is passed' do      
      stub_request(:get, catalogue_url+'/packages?page_number='+default_page_number+'&page_size=1').to_return(status: 200, body: [package_1_metadata].to_json, headers: {'content-type' => 'application/json'})
      expect(described_class.metadata({page_size: 1})).to eq([package_1_metadata])
    end
    it 'calls the Catalogue with default page_number and page_size, returning existing packages' do      
      stub_request(:get, catalogue_url+'/packages?page_number='+default_page_number+'&page_size='+default_page_size).
        to_return(status: 200, body: packages_metadata.to_json, headers: {'content-type' => 'application/json'})
      expect(described_class.metadata({page_size: default_page_size, page_number: default_page_number})).to eq(packages_metadata)
    end
    context 'calls the Catalogue with the passed UUID' do
      it 'return Ok (200) for existing UUIDs' do      
        stub_request(:get, catalogue_url+'/packages/'+uuid_1).to_return(status: 200, body: package_1_metadata.to_json, headers: {'content-type' => 'application/json'})
        expect(described_class.metadata({package_uuid: uuid_1})).to eq(package_1_metadata)
      end
      it 'return Not Found (404) for non-existing UUIDs' do      
        stub_request(:get, catalogue_url+'/packages/'+uuid_1).to_return(status: 404, body: '', headers: {'content-type' => 'application/json'})
        expect(described_class.metadata({package_uuid: uuid_1})).to be_falsy
      end
    end
  end
  
  describe '.package_file' do
    let(:package_uuid) {SecureRandom.uuid}
    let(:package_file_uuid) {SecureRandom.uuid}
    let(:package_file_name) {'whatever_name.tgo'}
    let(:no_file_uuid_package_metadata) {{
      uuid: package_uuid, 
      pd: {vendor: '5gtango', name: 'whatever', version: '0.0.1', package_file_uuid: '', package_file_name: package_file_name}
    }}
    let(:no_file_name_package_metadata) {{
      uuid: package_uuid, 
      pd: {vendor: '5gtango', name: 'whatever', version: '0.0.1', package_file_uuid: package_file_uuid, package_file_name: ''}
    }}
    let(:package_metadata) {{
      uuid: package_uuid, 
      pd: {vendor: '5gtango', name: 'whatever', version: '0.0.1', package_file_uuid: package_file_uuid, package_file_name: package_file_name}
    }}
    #let(:file_data) { File.open(File.join(File.dirname(__FILE__),'..','fixtures','5gtango-ns-package-example.tgo'), 'rb')}
    let(:file_data) { object_double('file double')}
    

    it 'rejects calls with non-existing packages' do
      allow(described_class).to receive(:metadata).with(package_uuid: package_uuid).and_return(nil)
      expect(described_class.package_file({package_uuid: package_uuid})).to eq([nil, nil])
    end
    it 'rejects calls for existing packages without package_file_id defined' do
      allow(described_class).to receive(:metadata).with(package_uuid: package_uuid).and_return(no_file_uuid_package_metadata)
      expect(described_class.package_file({package_uuid:package_uuid})).to eq([nil, nil])
    end
    # 
    it 'rejects calls for existing packages without package_file_name defined' do
      allow(described_class).to receive(:metadata).with(package_uuid: package_uuid).and_return(no_file_name_package_metadata)
      expect(described_class.package_file({package_uuid: package_uuid})).to eq([nil, nil])
    end
    it 'accepts calls for existing packages with package_file_name defined and returns file content' do
      allow(described_class).to receive(:metadata).with(package_uuid: package_uuid).and_return(package_metadata)
      WebMock.stub_request(:get, catalogue_url+'/tgo-packages/'+package_file_uuid).to_return(body: 'xyz', status: 200)
      expect(described_class.package_file({package_uuid: package_uuid})).to eq(['xyz', {}])
    end
  end
  
  describe '.file_by_uuid' do
    let(:package_uuid) {SecureRandom.uuid}
    let(:file_uuid) {SecureRandom.uuid}
    let(:non_existing_file_uuid) {SecureRandom.uuid}
    let(:file_content) {'abc.xyz'}
    let(:package_metadata) {{
      uuid: package_uuid, 
      pd: {
        vendor: '5gtango', name: 'whatever', version: '0.0.1', 
        package_content: [{
          :"content-type" => "application/vnd.5gtango.nsd", 
          source: "Definitions/mynsd.yaml", 
          uuid: file_uuid
        }]
      }
    }}
    it 'rejects calls with non-existing files' do
      allow(described_class).to receive(:metadata).with(package_uuid: package_uuid).and_return(package_metadata)
      WebMock.stub_request(:get, catalogue_url+'/files/'+file_uuid).to_return(body: file_content, status: 200)
      expect(described_class.file_by_uuid({package_uuid: package_uuid, file_uuid: non_existing_file_uuid})).to eq([nil, nil])
    end
    it 'accepts calls for existing files, returning their body' do
      allow(described_class).to receive(:metadata).with(package_uuid: package_uuid).and_return(package_metadata)
      WebMock.stub_request(:get, catalogue_url+'/files/'+file_uuid).to_return(body: file_content, status: 200)
      expect(described_class.file_by_uuid({package_uuid: package_uuid, file_uuid: file_uuid})).to eq([file_content, {}])
    end
  end
end